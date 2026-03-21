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
@startuml\nskinparam backgroundColor #1e293b
skinparam shadowing false
skinparam defaultFontName Inter
skinparam defaultFontColor #f8fafc
skinparam ArrowColor #2c7a7b
skinparam classBackgroundColor #2D3748
skinparam classFontColor #f8fafc
skinparam classBorderColor #2c7a7b
skinparam EntityBackgroundColor #2D3748
skinparam EntityBorderColor #2c7a7b
skinparam ActorBackgroundColor #2D3748
skinparam ActorBorderColor #81E6D9
skinparam ActorFontColor #f8fafc
skinparam ParticipantBackgroundColor #2D3748
skinparam ParticipantBorderColor #2c7a7b
skinparam ParticipantFontColor #f8fafc
skinparam DatabaseBackgroundColor #2D3748
skinparam DatabaseBorderColor #2c7a7b
skinparam DatabaseFontColor #f8fafc
skinparam NoteBackgroundColor #2D3748
skinparam NoteBorderColor #2c7a7b
skinparam NoteFontColor #f8fafc
\nskinparam defaultFontName Inter
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

```kroki-plantuml
@startuml\nskinparam backgroundColor #1e293b
skinparam shadowing false
skinparam defaultFontName Inter
skinparam defaultFontColor #f8fafc
skinparam ArrowColor #2c7a7b
skinparam classBackgroundColor #2D3748
skinparam classFontColor #f8fafc
skinparam classBorderColor #2c7a7b
skinparam EntityBackgroundColor #2D3748
skinparam EntityBorderColor #2c7a7b
skinparam ActorBackgroundColor #2D3748
skinparam ActorBorderColor #81E6D9
skinparam ActorFontColor #f8fafc
skinparam ParticipantBackgroundColor #2D3748
skinparam ParticipantBorderColor #2c7a7b
skinparam ParticipantFontColor #f8fafc
skinparam DatabaseBackgroundColor #2D3748
skinparam DatabaseBorderColor #2c7a7b
skinparam DatabaseFontColor #f8fafc
skinparam NoteBackgroundColor #2D3748
skinparam NoteBorderColor #2c7a7b
skinparam NoteFontColor #f8fafc
