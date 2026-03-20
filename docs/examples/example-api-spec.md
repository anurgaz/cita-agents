# API-003: POST /api/v1/public/{slug}/bookings

## Meta
- **Агент-автор:** SA
- **User Story:** US-003
- **Дата:** 2026-03-20
- **Статус:** Approved

## Endpoint
- **Method:** POST
- **Path:** /api/v1/public/{slug}/bookings
- **Auth:** Public (JWT не требуется)
- **Rate Limit:** нет (TODO: добавить)

## Path Parameters
| Параметр | Тип | Описание |
|----------|-----|----------|
| `slug` | string | URL-идентификатор бизнеса (например, `7001234567` или `salon-beauty`) |

## Request Body

```json
{
  "service_id": 1,
  "master_id": null,
  "date": "2026-03-25",
  "time": "10:00",
  "first_name": "Иван",
  "phone": "+77001234567",
  "notes": "Хочу короткую стрижку"
}
```

### Validation Rules
| Поле | Правило |
|------|---------|
| `service_id` | Integer, required. Должен существовать в рамках бизнеса |
| `master_id` | Integer, optional. Если null — auto-assign. Если указан — должен существовать и выполнять service_id |
| `date` | String, required. Формат YYYY-MM-DD. Не в прошлом |
| `time` | String, required. Формат HH:MM |
| `first_name` | String, required. Не пустая строка |
| `phone` | String, required. Не пустая строка |
| `notes` | String, optional |

## Response

### 201 Created

```json
{
  "id": 42,
  "status": "pending",
  "service": {
    "id": 1,
    "name": "Мужская стрижка",
    "duration": 60,
    "price": 5000.0
  },
  "master": {
    "id": 3,
    "name": "Алексей"
  },
  "date": "2026-03-25",
  "time": "10:00",
  "start_at": "2026-03-25T10:00:00",
  "end_at": "2026-03-25T11:00:00",
  "first_name": "Иван",
  "phone": "+77001234567",
  "price_snapshot": 5000.0
}
```

### Error Responses
| HTTP Code | Условие | Body |
|-----------|---------|------|
| 404 | Бизнес с данным slug не найден | `{"detail": "Business not found"}` |
| 404 | Услуга не найдена или не принадлежит бизнесу | `{"detail": "Service not found"}` |
| 400 | Мастер не выполняет указанную услугу | `{"detail": "Master does not provide this service"}` |
| 400 | Слот занят (пересечение с existing booking) | `{"detail": "Slot is not available"}` |
| 400 | Нет доступных мастеров для auto-assign | `{"detail": "No available masters"}` |
| 422 | Невалидный request body (Pydantic) | `{"detail": [{"loc": [...], "msg": "...", "type": "..."}]}` |

## Business Logic

### Алгоритм (файл: `backend/app/api/v1/endpoints/public.py`)

1. **Найти бизнес** по slug. Если не найден -> 404.
2. **Найти услугу** по service_id в рамках бизнеса. Если не найдена -> 404.
3. **Определить мастера:**
   - Если `master_id` указан: проверить что мастер существует и имеет связь с услугой через `master_services`
   - Если `master_id = null`: Auto-assign (BR-001)
     - Получить всех мастеров бизнеса, связанных с услугой
     - Для каждого мастера проверить доступность слота (расписание + существующие записи)
     - Назначить первого свободного мастера
     - Если никто не свободен -> 400
4. **Проверить доступность слота** (BR-003):
   - Получить расписание мастера на день недели (SR-001: master schedule > business schedule)
   - Проверить что слот в рабочих часах
   - Проверить что слот не пересекается с перерывом (SR-005)
   - Проверить что нет пересечения с существующими записями (status in: pending, confirmed)
5. **Вычислить end_at:** `start_at + timedelta(minutes=service.duration)`
6. **Upsert Client** (BR-008):
   - Поиск Client по (business_id, phone)
   - Если найден — обновить first_name
   - Если нет — создать нового
7. **Создать Booking:**
   - status = `pending` (BR-002)
   - price_snapshot = service.price (BR-005)
8. **Отправить уведомление** провайдеру через Telegram (NR-001):
   - Найти Subscription(PROVIDER_BUSINESS, business_id)
   - Отправить сообщение с inline-кнопками (Подтвердить / Отклонить / Перенести)
   - Ошибка отправки не блокирует создание записи
9. **Вернуть** 201 с данными записи

## Side Effects
- Telegram уведомление провайдеру (async, не блокирует response)
- Upsert записи в таблице `clients`
- Запись в `bookings` с price_snapshot

## Related
- **Business Rules:** BR-001, BR-002, BR-003, BR-005, BR-008, NR-001
- **Scheduling Rules:** SR-001, SR-005
- **Data:** Booking, Client, Service, Master, Schedule, Subscription
- **Notifications:** NotificationService.notify_provider_new_booking()
