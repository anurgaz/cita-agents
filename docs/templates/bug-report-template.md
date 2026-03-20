# Bug Report Template (CS Agent)

## Инструкция для агента

1. Формат — GitHub Issue
2. `Bug ID` — формат BUG-{NNN}
3. `Steps to Reproduce` — минимум 3 шага, воспроизводимые
4. `Severity` — Critical (данные теряются / сервис падает), High (функция не работает), Medium (workaround есть), Low (косметика)
5. Включай HTTP request/response если баг в API
6. `Environment` — конкретная версия, браузер, устройство
7. Перед созданием — проверь нет ли дубликата в открытых issues

---

## Шаблон

```markdown
## BUG-{NNN}: {Краткое описание бага}*

### Severity*
{Critical / High / Medium / Low}

### Environment*
- **URL:** {https://cita.kz/...}
- **Browser/Client:** {Chrome 120 / Telegram iOS / API}
- **Device:** {Desktop / iPhone 15 / Android}
- **Дата:** {YYYY-MM-DD HH:MM}
- **Business slug:** {slug, если релевантно}

### Description*
{2-3 предложения. Что происходит vs что ожидалось.}

### Steps to Reproduce*
1. {Шаг 1}
2. {Шаг 2}
3. {Шаг 3}

### Expected Behavior*
{Что должно произойти}

### Actual Behavior*
{Что происходит на самом деле}

### Evidence (опционально)
{Скриншоты, логи, HTTP request/response}

```
Request: POST /api/v1/public/{slug}/bookings
Body: {...}
Response: 500 {"detail": "..."}
```

### Possible Cause (опционально)
{Гипотеза: какой компонент/файл может быть причиной}

### Workaround (опционально)
{Как обойти баг до фикса}

### Related
- {Issue #NNN}
- {Business Rule BR-NNN}

### Labels
`bug`, `{severity}`, `{component: backend/frontend/miniapp/telegram}`
```

---

## Мини-пример

```markdown
## BUG-012: Двойная запись при быстром нажатии кнопки

### Severity
High

### Environment
- **URL:** https://cita.kz/salon-beauty
- **Browser/Client:** Telegram Mini App (iOS)
- **Device:** iPhone 15
- **Дата:** 2026-03-20 14:30

### Description
При быстром двойном нажатии кнопки "Записаться" создаются две одинаковые записи
на одно время. Ожидается что вторая попытка будет отклонена как занятый слот.

### Steps to Reproduce
1. Открыть Mini App, выбрать услугу, дату, время
2. Быстро нажать "Записаться" два раза подряд
3. Проверить список записей

### Expected Behavior
Одна запись создана, вторая отклонена (слот занят).

### Actual Behavior
Две записи с одинаковым временем в статусе `pending`.

### Possible Cause
Нет блокировки повторного нажатия на фронте (debounce).
На бэкенде нет unique constraint на (master_id, start_at, status).

### Labels
`bug`, `high`, `miniapp`, `backend`
```
