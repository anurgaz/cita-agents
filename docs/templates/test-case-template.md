# Test Case Template (SA Agent)

## Инструкция для агента

1. `Test ID` — формат TC-{NNN}
2. Покрывай каждый Acceptance Criteria из User Story
3. Включай позитивные, негативные и граничные случаи
4. `Preconditions` — конкретное состояние БД/системы
5. `Steps` — пронумерованные, воспроизводимые
6. `Expected Result` — проверяемый (конкретные значения, HTTP коды, состояние БД)

---

## Шаблон

```markdown
# TC-{NNN}: {Название тест-кейса}*

## Meta
- **Агент-автор:** SA
- **User Story:** US-{NNN}*
- **AC:** AC-{N}*
- **Тип:** {Positive / Negative / Boundary / Integration}*
- **Приоритет:** {Critical / High / Medium / Low}*
- **Дата:** {YYYY-MM-DD}*

## Preconditions*
- {Состояние системы перед тестом}
- {Тестовые данные}

## Steps*
1. {Действие 1}
2. {Действие 2}
3. ...

## Expected Result*
- {Что должно произойти}
- HTTP Response: {code}
- DB State: {что изменилось}

## Postconditions (опционально)
- {Состояние после теста, cleanup}

## Test Data (опционально)
| Параметр | Значение |
|----------|----------|
| {param} | {value} |
```

---

## Мини-пример

```markdown
# TC-007: Создание записи на занятый слот

## Meta
- **Агент-автор:** SA
- **User Story:** US-003
- **AC:** AC-3
- **Тип:** Negative
- **Приоритет:** Critical
- **Дата:** 2026-03-20

## Preconditions
- Бизнес slug=`test-salon` существует
- Мастер id=1 с услугой id=1 (duration=60 min)
- Запись на 2026-03-25 10:00 уже существует (status=confirmed)

## Steps
1. POST /api/v1/public/test-salon/bookings
2. Body: `{"service_id":1, "master_id":1, "date":"2026-03-25", "time":"10:00", "first_name":"Test", "phone":"+70000000000"}`

## Expected Result
- HTTP 400
- Body: `{"detail": "Slot is not available"}`
- Новая запись в БД НЕ создана
```
