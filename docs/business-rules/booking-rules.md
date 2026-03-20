# Booking Rules — Правила бронирования

> Извлечено из кода: backend/app/api/v1/endpoints/public.py, backend/app/models/booking.py,
> backend/app/services/availability.py, backend/app/schemas/public.py

---

## BR-001: Создание записи через публичный API

- **Описание:** Клиент создаёт бронирование через POST /public/{slug}/booking без авторизации
- **Условие:** Клиент отправляет: service_id, date, time, first_name, phone. Опционально: master_id, notes, recaptcha_token
- **Действие:**
  1. Валидация reCAPTCHA (если token передан и RECAPTCHA_SECRET_KEY настроен)
  2. Поиск бизнеса по slug — 404 если не найден
  3. Поиск услуги по service_id — 404 если не найдена
  4. Resolve master_id (см. BR-002)
  5. Поиск/создание Client по phone + business_id (см. BR-003)
  6. Расчёт end_at = start_at + service.duration минут
  7. Нормализация телефона: убрать +, -, пробелы; если 10 цифр — добавить 7
  8. Создание Booking со статусом "pending", price_snapshot = service.price
  9. Отправка Telegram-уведомления провайдеру (inline-кнопки: подтвердить/отклонить/перенести)
  10. Возврат BookingResponse с telegram_url для подписки клиента
- **Исключения:**
  - reCAPTCHA не настроена (RECAPTCHA_SECRET_KEY пустой) — проверка пропускается
  - master_id=null — автоназначение (BR-002)
- **Источник в коде:** `backend/app/api/v1/endpoints/public.py::create_booking()`

---

## BR-002: Автоназначение мастера

- **Описание:** Если клиент не выбрал мастера, система назначает автоматически
- **Условие:** master_id = null в запросе на бронирование
- **Действие:**
  1. Поиск мастера через M2M таблицу master_services, привязанного к выбранной услуге (LIMIT 1)
  2. Если не найден — поиск любого мастера бизнеса (LIMIT 1)
  3. Если мастеров нет вообще — HTTP 400 "No masters available"
- **Исключения:**
  - Алгоритм берёт первого найденного (по порядку в БД), без учёта загруженности
  - Все записи могут попасть к одному мастеру
- **Источник в коде:** `backend/app/api/v1/endpoints/public.py::create_booking()` (строки 206-229)

---

## BR-003: Создание/обновление клиента при записи

- **Описание:** При каждой записи система ищет или создаёт клиента
- **Условие:** Каждый POST booking
- **Действие:**
  1. SELECT Client WHERE phone = booking.phone AND business_id = business.id
  2. Если не найден — INSERT новый Client (phone, first_name, notes, business_id)
  3. Если найден — обновить first_name (если передан), дописать notes через перенос строки
- **Исключения:**
  - Client привязан к конкретному бизнесу (один телефон = разные Client в разных бизнесах)
  - Notes накапливаются (append, не replace)
- **Источник в коде:** `backend/app/api/v1/endpoints/public.py::create_booking()` (строки 231-255)

---

## BR-004: Жизненный цикл статусов бронирования

- **Описание:** Booking имеет жизненный цикл статусов
- **Условие:** Любое изменение статуса
- **Действие:**
  - pending -> confirmed (провайдер подтвердил)
  - pending -> cancelled (провайдер отклонил через reject)
  - pending -> rejected (провайдер отклонил — зарезервировано)
  - confirmed -> completed (запись завершена)
  - confirmed -> cancelled (провайдер отменил)
- **Исключения:**
  - В коде НЕТ валидации переходов — PATCH /bookings/{id} принимает любой status без проверки текущего
  - Telegram callback confirm/reject работает ТОЛЬКО из pending (проверка: booking.status not in ["pending"])
  - Клиент НЕ может менять статус (нет endpoint)
- **Источник в коде:**
  - Модель: `backend/app/models/booking.py::BookingStatus`
  - API: `backend/app/api/v1/endpoints/bookings.py::update_booking_status()`
  - Telegram: `backend/app/services/telegram_handler.py::_handle_confirm_reject()`

---

## BR-005: Фиксация цены при бронировании (Price Snapshot)

- **Описание:** Цена услуги копируется в booking при создании и не меняется
- **Условие:** POST booking
- **Действие:** booking.price_snapshot = service.price — значение на момент создания
- **Исключения:**
  - Если Service.price изменится после создания booking — price_snapshot остаётся прежним
  - Аналитика (ClickHouse) использует price_snapshot, не текущую цену услуги
- **Источник в коде:** `backend/app/api/v1/endpoints/public.py::create_booking()` (строка 277)

---

## BR-006: Расчёт времени окончания записи

- **Описание:** end_at вычисляется автоматически из start_at + duration
- **Условие:** POST booking
- **Действие:**
  1. start_dt = datetime.combine(date, time)
  2. end_dt = start_dt + timedelta(minutes=service.duration)
- **Исключения:**
  - Время хранится как naive datetime (без timezone)
  - Нет проверки, что end_at не выходит за рабочие часы
  - Нет проверки overlap с другими записями (TODO в коде)
- **Источник в коде:** `backend/app/api/v1/endpoints/public.py::create_booking()` (строки 258-259)

---

## BR-007: Проверка доступности слота — НЕ реализована при записи

- **Описание:** При создании записи бэкенд НЕ проверяет, свободен ли слот
- **Условие:** POST booking
- **Действие:** Запись создаётся без проверки overlap. Комментарий в коде: "TODO: Check overlap again to be safe?"
- **Исключения:**
  - Race condition: два клиента одновременно бронируют один слот — оба успешно
  - Фронтенд проверяет слоты через GET /slots, но это не гарантирует атомарность
- **Источник в коде:** `backend/app/api/v1/endpoints/public.py::create_booking()` (строки 261-262)

---

## BR-008: Подтверждение/отклонение через Telegram

- **Описание:** Провайдер подтверждает или отклоняет запись через inline-кнопки в Telegram
- **Условие:** Провайдер нажимает кнопку подтверждения или отклонения на сообщении о новой записи
- **Действие:**
  1. Проверка: booking существует
  2. Проверка: business.telegram_chat_id == текущий chat_id (авторизация)
  3. Проверка: booking.status == "pending" (нельзя повторно обработать)
  4. Обновление статуса: confirm -> "confirmed", reject -> "cancelled"
  5. Редактирование исходного сообщения (убираются кнопки)
  6. Уведомление клиента о смене статуса
- **Исключения:**
  - reject ставит статус "cancelled", а не "rejected"
  - Если бот-сообщение удалено — edit_message упадёт, но ошибка ловится
- **Источник в коде:** `backend/app/services/telegram_handler.py::_handle_confirm_reject()`

---

## BR-009: Удаление записи (hard delete)

- **Описание:** Провайдер может удалить запись через админку
- **Условие:** DELETE /bookings/{id}
- **Действие:**
  1. Поиск booking по id + business_id (авторизация)
  2. Если статус не "cancelled" — ставит "cancelled" и отправляет уведомление клиенту
  3. Удаляет запись из БД (hard delete)
- **Исключения:**
  - Hard delete — запись пропадает из БД навсегда (нет soft delete)
  - Клиент получает уведомление "Запись ОТМЕНЕНА" перед удалением
- **Источник в коде:** `backend/app/api/v1/endpoints/bookings.py::delete_booking()`

---

## BR-010: Нормализация телефона

- **Описание:** Телефон клиента нормализуется при создании записи
- **Условие:** POST booking
- **Действие:**
  1. Убираются символы: +, -, пробелы
  2. Если осталось 10 цифр — добавляется "7" в начало (казахстанский формат)
- **Исключения:**
  - Формат результата: 11 цифр без + (например, 77017017001)
  - При поиске подписок используются варианты: с +, без +, с 8 вместо 7
- **Источник в коде:** `backend/app/api/v1/endpoints/public.py::create_booking()` (строки 265-267)

---

## BR-011: Лимит записей в день — НЕ реализован

- **Описание:** Нет ограничения на количество записей одного клиента в день
- **Условие:** —
- **Действие:** TODO: не реализовано
- **Исключения:** Клиент может создать неограниченное количество записей на одну дату
- **Источник в коде:** Отсутствует

---

## BR-012: Telegram URL в ответе на бронирование

- **Описание:** После создания записи клиенту возвращается ссылка для подписки в Telegram
- **Условие:** Каждый успешный POST booking
- **Действие:** Генерируется URL: https://t.me/citakz_bot?start=client_{booking_id}
- **Исключения:**
  - URL всегда возвращается, даже если у бизнеса нет Telegram-подписки
  - Клиент может проигнорировать ссылку — тогда уведомления не придут
- **Источник в коде:** `backend/app/api/v1/endpoints/public.py::create_booking()` (строка 302)
