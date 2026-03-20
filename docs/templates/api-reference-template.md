# API Reference Template (TW Agent)

## Инструкция для агента

1. Один файл = один endpoint (как api-spec, но для внешней документации)
2. Язык — английский (API docs)
3. Включай curl-примеры
4. Response — реальные примеры данных (не схемы)
5. Сверяй с кодом: endpoint path, method, auth, request/response body
6. Отличие от api-spec-template: здесь нет business logic, только usage

---

## Шаблон

```markdown
# {METHOD} {path}*

{Одно предложение - что делает endpoint.}*

## Authentication*
{Public / Bearer JWT / Superadmin JWT}

## Parameters

### Path Parameters
| Name | Type | Description |
|------|------|-------------|
| `{param}` | {type} | {description} |

### Query Parameters (если есть)
| Name | Type | Required | Default | Description |
|------|------|:---:|---------|-------------|
| `{param}` | {type} | {Yes/No} | {value} | {description} |

### Request Body (если есть)
| Field | Type | Required | Description |
|-------|------|:---:|-------------|
| `{field}` | {type} | {Yes/No} | {description} |

## Example Request*

```bash
curl -X {METHOD} https://cita.kz/api/v1/{path} \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{json}'
```

## Example Response*

### Success ({code})
```json
{response body}
```

### Error ({code})
```json
{"detail": "..."}
```

## Notes (опционально)
- {Важные замечания для разработчика-потребителя}
```

---

## Мини-пример

```markdown
# GET /api/v1/public/{slug}/slots

Returns available time slots for a given date and optional master.

## Authentication
Public (no token required)

## Parameters

### Path Parameters
| Name | Type | Description |
|------|------|-------------|
| `slug` | string | Business URL slug |

### Query Parameters
| Name | Type | Required | Default | Description |
|------|------|:---:|---------|-------------|
| `date` | string | Yes | - | Date in YYYY-MM-DD format |
| `master_id` | integer | No | null | Filter by master |

## Example Request

```bash
curl https://cita.kz/api/v1/public/salon-beauty/slots?date=2026-03-25
```

## Example Response

### Success (200)
```json
[
  {"time": "09:00", "available": true},
  {"time": "10:00", "available": true},
  {"time": "11:00", "available": false}
]
```

## Notes
- Slot step equals service duration
- Break times are excluded automatically
```
