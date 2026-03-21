# Test Diagrams

Тестовый файл: 4 диаграммы в правильных форматах.

## 1. Flowchart (Mermaid)

```mermaid
graph LR
    A["Клиент открывает Mini App"] --> B{"Авторизован?"}
    B -->|Да| C["Показать список услуг"]
    B -->|Нет| D["Показать экран входа"]
    D --> E["Telegram initData"]
    E --> C
    C --> F["Выбрать услугу"]
    F --> G["Выбрать мастера"]
    G --> H["Выбрать слот"]
    H --> I["Подтвердить бронирование"]
```

## 2. ER Diagram (Mermaid)

```mermaid
erDiagram
    BUSINESS ||--o{ MASTER : has
    BUSINESS ||--o{ SERVICE : offers
    MASTER ||--o{ SCHEDULE : has
    MASTER ||--o{ BOOKING : performs
    CLIENT ||--o{ BOOKING : makes
    SERVICE ||--o{ BOOKING : includes
    BOOKING {
        uuid id PK
        uuid client_id FK
        uuid master_id FK
        uuid service_id FK
        timestamp start_time
        int duration_min
        string status
        int price_snapshot
    }
    CLIENT {
        uuid id PK
        bigint telegram_id
        string first_name
        string phone
    }
    MASTER {
        uuid id PK
        uuid business_id FK
        string name
        boolean is_active
    }
    SERVICE {
        uuid id PK
        uuid business_id FK
        string name
        int duration_min
        int price
    }
    SCHEDULE {
        uuid id PK
        uuid master_id FK
        int day_of_week
        time start_time
        time end_time
    }
```

## 3. Sequence Diagram (PlantUML)

```plantuml
@startuml
skinparam backgroundColor #1e293b
skinparam shadowing false
skinparam defaultFontName Inter
skinparam defaultFontColor #f8fafc
skinparam ArrowColor #2c7a7b

title Создание бронирования

participant "Клиент" as Client
participant "Mini App" as Mini
participant "Backend" as API
database "PostgreSQL" as DB
participant "Telegram API" as TG

Client -> Mini: Выбирает слот и нажимает "Записаться"
Mini -> API: POST /api/v1/bookings
activate API

API -> DB: SELECT slot availability
DB --> API: slot data

note right of API
    BR-001: Проверка доступности
    BR-005: price_snapshot фиксируется
end note

alt Слот свободен
    API -> DB: INSERT INTO bookings
    DB --> API: booking record
    API -> TG: sendMessage (уведомление мастеру)
    TG --> API: ok
    API --> Mini: 201 Created
else Слот занят
    API --> Mini: 409 Conflict
end

deactivate API
Mini --> Client: Результат

@enduml
```

## 4. C4 Context Diagram (PlantUML)

```plantuml
@startuml
!include <C4/C4_Context>

title C4 Context: cita.kz

Person(client, "Клиент", "Записывается на услуги через Telegram Mini App")
Person(owner, "Владелец бизнеса", "Управляет салоном, расписанием, мастерами")

System(cita, "cita.kz", "Сервис онлайн-записи для салонов красоты")

System_Ext(telegram, "Telegram", "Мессенджер: Bot API + Mini App SDK")
System_Ext(twogis, "2GIS", "Suggest API для поиска адресов")

Rel(client, cita, "Записывается", "HTTPS / WebApp")
Rel(owner, cita, "Управляет", "HTTPS / WebApp")
Rel(cita, telegram, "Уведомления, WebApp", "Bot API")
Rel(cita, twogis, "Поиск адресов", "REST API")

@enduml
```
