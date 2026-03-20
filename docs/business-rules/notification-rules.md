# Notification Rules — Правила уведомлений

> Извлечено из кода: backend/app/services/notification.py, backend/app/services/telegram_bot.py,
> backend/app/services/telegram_handler.py, backend/app/models/notification.py

---

## NR-001: Уведомление провайдеру о новой записи

- **Описание:** При создании записи провайдер получает Telegram-сообщение
- **Условие:** Каждый успешный POST /public/{slug}/booking
- **Действие:**
  1. Поиск активной Subscription: context_type=PROVIDER_BUSINESS, context_ref=business_id
  2. Если подписка найдена — отправка сообщения с деталями и inline-кнопками:
     - Подтвердить (confirm_{booking_id})
     - Отклонить (reject_{booking_id})
     - Перенести (reschedule_{booking_id})
  3. Формат: клиент, телефон, услуга, мастер, дата, время, цена, комментарий
- **Исключения:**
  - Если подписки нет — уведомление НЕ отправляется (warning в логах)
  - Нет retry при ошибке отправки — ошибка логируется, запись создаётся
  - Цена берётся из price_snapshot или service.price (fallback)
- **Источник в коде:** `backend/app/services/notification.py::notify_provider_new_booking()`

---

## NR-002: Уведомление клиенту о смене статуса

- **Описание:** Клиент получает Telegram-уведомление при подтверждении/отмене записи
- **Условие:** PATCH /bookings/{id} или Telegram callback (confirm/reject)
- **Действие:**
  1. Поиск подписки клиента (приоритет):
     a. CLIENT_BOOKING (по booking_id) — самый надёжный
     b. CLIENT_PHONE (по телефону, с вариантами +7/7/8) — если booking subscription нет
  2. Формат сообщения зависит от статуса:
     - confirmed: "Запись ПОДТВЕРЖДЕНА" + название бизнеса, услуга, мастер, дата, время, адрес
     - cancelled: "Запись ОТМЕНЕНА" + предложение записаться снова
     - completed: "Запись ЗАВЕРШЕНА"
  3. Статусы pending и rejected НЕ уведомляются
- **Исключения:**
  - Если подписки нет — уведомление не отправляется (warning в логах)
  - Нормализация телефона: 8XXXXXXXXXX -> 7XXXXXXXXXX для поиска
  - Нет retry при ошибке
- **Источник в коде:** `backend/app/services/notification.py::notify_client_booking_status()`

---

## NR-003: Уведомление клиенту о предложении переноса

- **Описание:** Когда провайдер предлагает перенос — клиент получает Telegram-сообщение
- **Условие:** POST /reschedule/{booking_id} или Telegram callback reschedule
- **Действие:**
  1. Поиск подписки (аналогично NR-002)
  2. Сообщение: старое время, новое время, услуга + кнопки:
     - Подтвердить (ra_{proposal_id})
     - Отклонить (rd_{proposal_id})
  3. Возвращает True/False — отправлено или нет
- **Исключения:**
  - Если подписки нет — возвращает False (proposal создаётся, но клиент не узнает)
- **Источник в коде:** `backend/app/services/notification.py::notify_client_reschedule_proposal()`

---

## NR-004: Уведомление провайдеру о решении клиента по переносу

- **Описание:** Провайдер узнаёт, принял ли клиент перенос
- **Условие:** Клиент нажал кнопку ra_ или rd_ в Telegram
- **Действие:**
  1. Поиск PROVIDER_BUSINESS подписки по business_id
  2. Если принят: "Клиент подтвердил перенос" + новое время
  3. Если отклонён: "Клиент отклонил перенос" + предложенное время + текущее время
- **Исключения:**
  - Если подписки провайдера нет — уведомление не отправляется (silent)
- **Источник в коде:** `backend/app/services/notification.py::notify_provider_reschedule_result()`

---

## NR-005: Канал уведомлений — только Telegram

- **Описание:** Все уведомления отправляются только через Telegram Bot API
- **Условие:** Любое уведомление
- **Действие:** httpx POST -> api.telegram.org/bot{TOKEN}/sendMessage (parse_mode=Markdown)
- **Исключения:**
  - Нет SMS, нет email, нет web push, нет WhatsApp
  - В модели Subscription есть enum для WHATSAPP и SMS — но они не используются
  - Если клиент не подписан в Telegram — он НЕ получит уведомление
- **Источник в коде:** `backend/app/services/telegram_bot.py::TelegramBotService`

---

## NR-006: Подписка провайдера на уведомления

- **Описание:** Провайдер подключает Telegram через deep link
- **Условие:** Провайдер нажимает "Уведомления в Telegram" в админке
- **Действие:**
  1. Генерируется URL: t.me/citakz_bot?start=provider_{business_id}
  2. Бот получает /start provider_{business_id}
  3. Поиск Business по ID
  4. Обновление business.telegram_chat_id = chat_id
  5. Создание/активация Subscription (PROVIDER_BUSINESS)
  6. Отправка приветствия + QR-код для клиентов
- **Исключения:**
  - Один бизнес = один telegram_chat_id (если подключить из другого чата — старый отвалится)
  - QR-код генерируется server-side (Pillow + qrcode) и отправляется как фото
- **Источник в коде:** `backend/app/services/telegram_handler.py::_link_provider_by_phone()`

---

## NR-007: Подписка клиента на уведомления

- **Описание:** Клиент подписывается через deep link после записи
- **Условие:** Клиент переходит по ссылке t.me/citakz_bot?start=client_{booking_id}
- **Действие:**
  1. Поиск Booking по ID
  2. Создание двух подписок:
     a. CLIENT_PHONE (по телефону из booking) — для будущих записей
     b. CLIENT_BOOKING (по booking_id) — для конкретной записи
  3. Отправка status-aware сообщения (текст зависит от текущего статуса записи)
- **Исключения:**
  - Если booking не найден — сообщение "Запись не найдена"
  - Подписка CLIENT_PHONE позволяет получать уведомления о ВСЕХ записях с этим телефоном
- **Источник в коде:** `backend/app/services/telegram_handler.py::_link_client_booking()`

---

## NR-008: Подписка клиента по телефону (subscribe deep link)

- **Описание:** Прямая подписка по номеру телефона без привязки к конкретной записи
- **Условие:** Deep link: t.me/citakz_bot?start=subscribe_{phone}
- **Действие:**
  1. Создание CLIENT_PHONE подписки
  2. Поиск ВСЕХ активных записей (pending/confirmed) с этим телефоном
  3. Создание CLIENT_BOOKING подписок для каждой найденной записи
- **Исключения:**
  - Телефон НЕ верифицируется (комментарий в коде: "Insecure if phone is not verified")
  - Варианты телефона: с + и без +
- **Источник в коде:** `backend/app/services/telegram_handler.py::_link_client_phone()`

---

## NR-009: Отписка от уведомлений

- **Описание:** Клиент или провайдер может отписаться от всех уведомлений
- **Условие:** Команда /unsubscribe в боте
- **Действие:**
  1. Деактивация ВСЕХ подписок этого chat_id (is_active=False)
  2. Сообщение: "Вы отписались от N уведомлений"
- **Исключения:**
  - Отписка глобальная — все типы подписок одновременно
  - Нельзя отписаться выборочно (от одного бизнеса/записи)
- **Источник в коде:** `backend/app/services/telegram_handler.py::_handle_unsubscribe()`

---

## NR-010: Retry при ошибке отправки — НЕ реализован

- **Описание:** При ошибке отправки Telegram-сообщения нет retry
- **Условие:** httpx.HTTPError или Telegram API error
- **Действие:** Ошибка логируется, выполнение продолжается. Уведомление теряется.
- **Исключения:** TODO: не реализовано. Нет очереди, нет retry, нет dead letter
- **Источник в коде:** `backend/app/services/telegram_bot.py::send_message()` (try/except -> return None)

---

## NR-011: Напоминания перед записью — НЕ реализованы

- **Описание:** Нет автоматических напоминаний клиенту за N часов до записи
- **Условие:** —
- **Действие:** TODO: не реализовано
- **Исключения:** Нет cron-job, нет scheduled tasks, нет background worker
- **Источник в коде:** Отсутствует

---

## NR-012: Формат Telegram-сообщений

- **Описание:** Все сообщения используют Markdown parse_mode
- **Условие:** Любая отправка через bot_service
- **Действие:**
  - parse_mode: "Markdown"
  - Жирный текст: *текст*
  - Inline-кнопки: JSON inline_keyboard
  - callback_data формат: prefix_UUID (максимум ~45 байт из 64 лимита)
- **Исключения:**
  - Markdown v1 (не MarkdownV2) — некоторые спецсимволы могут ломать форматирование
  - Нет escape для спецсимволов в именах клиентов/услуг
- **Источник в коде:** `backend/app/services/telegram_bot.py`
