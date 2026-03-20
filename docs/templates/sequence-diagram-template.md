# Sequence Diagram Template (SA Agent, PlantUML)

## Инструкция для агента

1. Используй PlantUML синтаксис
2. Участники (participants) — именуй по архитектурным компонентам: Client, MiniApp, Backend, DB, TelegramAPI, 2GIS
3. Каждый вызов — указывай HTTP method + path или SQL-операцию
4. Группируй логику через `alt`, `opt`, `loop`, `group`
5. Добавляй `note` для бизнес-правил (ссылки BR-NNN, SR-NNN)
6. Диаграмма должна соответствовать API spec (API-NNN)

---

## Шаблон

```markdown
# SEQ-{NNN}: {Название сценария}*

## Meta
- **Агент-автор:** SA
- **User Story:** US-{NNN}*
- **API Spec:** API-{NNN}*
- **Дата:** {YYYY-MM-DD}*

## Описание
{1-2 предложения о сценарии}

## Диаграмма

```kroki-plantuml
@startuml
title {Название сценария}

participant "{Actor}" as Actor
participant "{Component 1}" as C1
participant "{Component 2}" as C2
database "{DB}" as DB

Actor -> C1: {действие}
activate C1

C1 -> C2: {HTTP METHOD /path}
activate C2

C2 -> DB: {SQL операция}
DB --> C2: {результат}

note right of C2
  {Бизнес-правило BR-NNN}
end note

alt {условие - успех}
  C2 --> C1: 200 OK
else {условие - ошибка}
  C2 --> C1: 4xx Error
end

deactivate C2
C1 --> Actor: {результат}
deactivate C1

@enduml
```

## Примечания (опционально)
- {Дополнительные пояснения}
```

---

## Мини-пример

```kroki-plantuml
@startuml
title Клиент создает запись через Mini App

participant "Клиент" as Client
participant "MiniApp" as MA
participant "Backend" as BE
database "PostgreSQL" as DB
participant "Telegram API" as TG

Client -> MA: Нажимает "Записаться"
MA -> BE: POST /public/{slug}/bookings
activate BE

BE -> DB: SELECT service WHERE id=service_id
BE -> DB: SELECT master (auto-assign if null)

note right of BE
  BR-001: Auto-assign мастера
  BR-003: Проверка слота
end note

BE -> DB: INSERT booking (status=pending)
BE -> DB: UPSERT client by phone

BE ->> TG: sendMessage (уведомление провайдеру)
BE --> MA: 201 {id, status: pending}
deactivate BE

MA --> Client: "Заявка отправлена!"
@enduml
```
