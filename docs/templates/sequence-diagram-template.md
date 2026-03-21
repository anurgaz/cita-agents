# Sequence Diagram Template (SA Agent, PlantUML)

## Инструкция для агента

1. Используй **PlantUML** синтаксис для sequence diagram
2. Участники (participants) — именуй по архитектурным компонентам: Client, MiniApp, Backend, DB, TelegramAPI, 2GIS
3. Каждый вызов — указывай HTTP method + path или SQL-операцию
4. Группируй логику через `alt`, `opt`, `loop`, `group`
5. Добавляй `note` для бизнес-правил (ссылки BR-NNN, SR-NNN)
6. Диаграмма должна соответствовать API spec (API-NNN)

> **Правило выбора формата:**
> - Sequence diagram, C4 → PlantUML
> - Flowchart, ER diagram → Mermaid

---

## Шаблон

```markdown
# SEQ-{NNN}: {Название сценария}

## Meta
- **Агент-автор:** SA
- **User Story:** US-{NNN}
- **API Spec:** API-{NNN}
- **Дата:** {YYYY-MM-DD}

## Описание
{1-2 предложения о сценарии}

## Диаграмма

```plantuml
@startuml
skinparam backgroundColor #1e293b
skinparam shadowing false
skinparam defaultFontName Inter
skinparam defaultFontColor #f8fafc
skinparam ArrowColor #2c7a7b

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

```plantuml
@startuml
skinparam backgroundColor #1e293b
skinparam shadowing false
skinparam defaultFontName Inter
skinparam defaultFontColor #f8fafc
skinparam ArrowColor #2c7a7b

title Создание бронирования (happy path)

participant "Клиент" as Client
participant "Mini App" as Mini
participant "Backend" as API
database "PostgreSQL" as DB

Client -> Mini: Нажимает "Записаться"
Mini -> API: POST /api/v1/bookings
activate API

API -> DB: SELECT available slots
DB --> API: slots[]

alt Есть свободный слот
  API -> DB: INSERT INTO bookings
  DB --> API: booking_id
  note right of API
    BR-001: Проверка доступности слота
  end note
  API --> Mini: 201 Created
else Нет свободных слотов
  API --> Mini: 409 Conflict
end

deactivate API
Mini --> Client: Результат

@enduml
```
