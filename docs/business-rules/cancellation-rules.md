# Cancellation Rules — Правила отмен и переносов

> Извлечено из кода: backend/app/api/v1/endpoints/bookings.py, backend/app/api/v1/endpoints/reschedule.py,
> backend/app/services/telegram_handler.py, backend/app/models/booking.py

---

## CR-001: Отмена записи провайдером через админку

- **Описание:** Провайдер может отменить запись через PATCH или DELETE
- **Условие:** PATCH /bookings/{id} с status="cancelled" ИЛИ DELETE /bookings/{id}
- **Действие (PATCH):**
  1. Поиск booking по id + business_id (авторизация)
  2. Обновление status = "cancelled"
  3. Уведомление клиента через Telegram (если подписан)
- **Действие (DELETE):**
  1. Если статус не "cancelled" — сначала ставит "cancelled" и уведомляет
  2. Затем hard delete из БД
- **Исключения:**
  - PATCH не проверяет текущий статус — можно "отменить" уже завершённую запись
  - DELETE — необратимое удаление (нет корзины, нет soft delete)
  - Слот автоматически освобождается (запись удалена из busy intervals)
- **Источник в коде:**
  - `backend/app/api/v1/endpoints/bookings.py::update_booking_status()`
  - `backend/app/api/v1/endpoints/bookings.py::delete_booking()`

---

## CR-002: Отклонение записи через Telegram

- **Описание:** Провайдер отклоняет запись через inline-кнопку в Telegram
- **Условие:** Нажатие кнопки "Отклонить" (callback_data: reject_{booking_id})
- **Действие:**
  1. Проверка: booking.status == "pending" (только ожидающие)
  2. Проверка: business.telegram_chat_id == chat_id (авторизация)
  3. Статус -> "cancelled" (НЕ "rejected")
  4. Редактирование исходного сообщения (кнопки убираются)
  5. Уведомление клиенту: "Запись ОТМЕНЕНА"
- **Исключения:**
  - Работает только из статуса "pending"
  - Если запись уже обработана — ответ: "Запись уже обработана"
- **Источник в коде:** `backend/app/services/telegram_handler.py::_handle_confirm_reject()`

---

## CR-003: Отмена клиентом — НЕ реализована

- **Описание:** Клиент НЕ может самостоятельно отменить запись
- **Условие:** —
- **Действие:** TODO: не реализовано. Нет API endpoint для отмены клиентом. Нет Telegram-команды для отмены.
- **Исключения:** Клиент может только связаться с провайдером для отмены
- **Источник в коде:** Отсутствует

---

## CR-004: Перенос записи провайдером через API

- **Описание:** Провайдер предлагает клиенту новое время через RescheduleProposal
- **Условие:** POST /reschedule/{booking_id}
- **Действие:**
  1. Проверка: booking принадлежит бизнесу пользователя
  2. Проверка: booking.status in ["pending", "confirmed"]
  3. Проверка: нет существующего PENDING proposal
  4. Создание RescheduleProposal:
     - old_date, old_time: из текущего booking
     - proposed_date, proposed_time: из запроса
     - proposed_by: "PROVIDER_WEB"
     - status: PENDING
     - expires_at: now + 24 часа
  5. Уведомление клиенту (если подписан)
- **Исключения:**
  - Только один PENDING proposal на booking (HTTP 409 при дубле)
  - Нет проверки доступности предложенного слота через API
  - TTL: 24 часа
- **Источник в коде:** `backend/app/api/v1/endpoints/reschedule.py::create_reschedule_proposal()`

---

## CR-005: Перенос записи через Telegram (provider)

- **Описание:** Провайдер переносит запись через inline-кнопки в Telegram
- **Условие:** Нажатие кнопки "Перенести" (callback_data: reschedule_{booking_id})
- **Действие:**
  1. Проверка: status in ["pending", "confirmed"] и нет PENDING proposal
  2. Загрузка расписания + существующих записей на дату
  3. Расчёт доступных часов (шаг 15 мин, проверка busy minutes)
  4. Показ inline-клавиатуры с доступными часами (rh_{booking_id}_{hour})
  5. После выбора часа — показ минут: :00, :15, :30, :45 (rm_{booking_id}_{hour}_{min})
  6. Создание RescheduleProposal (proposed_by: "PROVIDER_BOT")
  7. Уведомление клиенту
- **Исключения:**
  - Перенос только на ТУ ЖЕ дату (через Telegram нельзя выбрать другую дату)
  - Через API (CR-004) можно выбрать любую дату
  - Если нет доступных слотов — "Нет доступного времени для переноса"
- **Источник в коде:** `backend/app/services/telegram_handler.py::_handle_reschedule_init()`

---

## CR-006: Принятие переноса клиентом

- **Описание:** Клиент принимает предложение переноса через Telegram
- **Условие:** Нажатие кнопки ra_{proposal_id} в Telegram
- **Действие:**
  1. Поиск proposal по ID
  2. Проверка: proposal.status == PENDING
  3. Обновление booking: start_at = proposed_date + proposed_time, end_at = start_at + duration
  4. proposal.status = ACCEPTED
  5. Уведомление провайдеру: "Клиент подтвердил перенос"
  6. Редактирование сообщения клиенту (убираются кнопки)
- **Исключения:**
  - Нет повторной проверки доступности слота при принятии (возможен overlap)
  - Если proposal expired — ответ: "Предложение истекло"
- **Источник в коде:** `backend/app/services/telegram_handler.py::_handle_reschedule_accept()`

---

## CR-007: Отклонение переноса клиентом

- **Описание:** Клиент отклоняет предложение переноса
- **Условие:** Нажатие кнопки rd_{proposal_id} в Telegram
- **Действие:**
  1. proposal.status = DECLINED
  2. Запись остаётся на прежнем времени (без изменений)
  3. Уведомление провайдеру: "Клиент отклонил перенос"
- **Исключения:**
  - Провайдер может создать новый proposal после отклонения
- **Источник в коде:** `backend/app/services/telegram_handler.py::_handle_reschedule_decline()`

---

## CR-008: Автоистечение предложения переноса

- **Описание:** RescheduleProposal автоматически истекает через 24 часа
- **Условие:** proposal.expires_at < now AND status == PENDING
- **Действие:**
  - Lazy expiration: статус меняется на EXPIRED при GET /reschedule/{booking_id}
  - Нет фонового процесса (no cron, no celery)
  - Запись остаётся на прежнем времени
- **Исключения:**
  - Если никто не запрашивает GET — proposal "висит" в PENDING бесконечно
  - Клиент может ответить на expired proposal до первого GET — поведение не определено
- **Источник в коде:** `backend/app/api/v1/endpoints/reschedule.py::get_reschedule_proposals()`

---

## CR-009: Ограничение на время отмены — НЕ реализовано

- **Описание:** Нет ограничения: "отменить можно только за N часов до записи"
- **Условие:** —
- **Действие:** TODO: не реализовано. Провайдер может отменить запись за 1 минуту до начала.
- **Исключения:** Клиент вообще не может отменить (см. CR-003)
- **Источник в коде:** Отсутствует

---

## CR-010: No-show обработка — НЕ реализована

- **Описание:** Нет автоматической обработки no-show (клиент не пришёл)
- **Условие:** —
- **Действие:** TODO: не реализовано. Нет статуса "no_show", нет cron-job для auto-complete/cancel
- **Исключения:**
  - Запись остаётся в "confirmed" навсегда, если провайдер не переведёт в "completed" или "cancelled" вручную
- **Источник в коде:** Отсутствует

---

## CR-011: Возврат слота при отмене

- **Описание:** При отмене записи слот автоматически становится доступным
- **Условие:** booking.status переходит в "cancelled" или "rejected", ИЛИ booking удаляется
- **Действие:**
  - AvailabilityService.get_bookings_for_date() фильтрует: status NOT IN ("cancelled", "rejected")
  - Отменённая запись исчезает из busy_intervals
  - Слот становится доступен для новых записей
- **Исключения:**
  - Нет уведомления "слот освободился" другим ожидающим клиентам (waitlist не реализован)
  - При hard delete (DELETE /bookings/{id}) — запись удалена, слот свободен автоматически
- **Источник в коде:** `backend/app/services/availability.py::get_bookings_for_date()` (строка 72)
