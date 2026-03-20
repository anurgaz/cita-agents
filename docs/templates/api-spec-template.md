# API Specification Template (SA Agent)

## Инструкция для агента

1. Один файл = один endpoint
2. `Endpoint ID` — формат API-{NNN}
3. Request/Response — полные JSON-схемы с типами
4. Error Responses — ВСЕ возможные HTTP-коды с примерами
5. `Business Logic` — пошаговый алгоритм, ссылки на business rules
6. `Security` — указать auth requirements, rate limits
7. Сверяй типы с data-dictionary.md

---

## Шаблон

```markdown
# API-{NNN}: {METHOD} {path}*

## Meta
- **Агент-автор:** SA
- **User Story:** US-{NNN}*
- **Дата:** {YYYY-MM-DD}*
- **Статус:** {Draft / Review / Approved}

## Endpoint*
- **Method:** {GET / POST / PUT / PATCH / DELETE}
- **Path:** {/api/v1/...}
- **Auth:** {Bearer JWT / Public / Superadmin}
- **Rate Limit:** {requests/min или "нет"}

## Path Parameters (если есть)
| Параметр | Тип | Описание |
|----------|-----|----------|
| {param} | {type} | {описание} |

## Query Parameters (если есть)
| Параметр | Тип | Обязательный | Default | Описание |
|----------|-----|:---:|---------|----------|
| {param} | {type} | {да/нет} | {value} | {описание} |

## Request Body (если есть)*
```json
{
  "field": "type — описание"
}
```

### Validation Rules
| Поле | Правило |
|------|---------|
| {field} | {min/max/regex/enum и т.д.} |

## Response*

### 200 OK / 201 Created
```json
{
  "field": "type — описание"
}
```

### Error Responses*
| HTTP Code | Условие | Body |
|-----------|---------|------|
| 400 | {когда} | `{"detail": "..."}` |
| 401 | {когда} | `{"detail": "..."}` |
| 404 | {когда} | `{"detail": "..."}` |
| 422 | {когда} | `{"detail": [...]}` |

## Business Logic*
1. {Шаг 1}
2. {Шаг 2}
3. ...

## Side Effects (опционально)
- {Какие побочные действия: уведомления, запись в лог, и т.д.}

## Related
- Business Rules: {BR-NNN, SR-NNN}
- Data: {ссылки на сущности из data-dictionary}
```

---

## Мини-пример

```markdown
# API-005: POST /api/v1/public/{slug}/bookings

## Meta
- **Агент-автор:** SA
- **User Story:** US-003
- **Дата:** 2026-03-20
- **Статус:** Draft

## Endpoint
- **Method:** POST
- **Path:** /api/v1/public/{slug}/bookings
- **Auth:** Public (без JWT)
- **Rate Limit:** нет

## Request Body
```json
{
  "service_id": 1,
  "master_id": null,
  "date": "2026-03-25",
  "time": "10:00",
  "first_name": "Иван",
  "phone": "+77001234567"
}
```

### 201 Created
```json
{
  "id": 42,
  "status": "pending",
  "start_at": "2026-03-25T10:00:00"
}
```
```
