# Data Dictionary

> Источник: `backend/app/models/auth.py`, `catalog.py`, `booking.py`, `notification.py`
> ORM: SQLAlchemy 2.0 (Mapped columns), PostgreSQL 16

---

## Business

> Таблица: `businesses`

| Поле | Тип | Обязательное | Описание | PII |
|------|-----|:---:|----------|:---:|
| `id` | Integer (PK) | да | Auto-increment ID | - |
| `slug` | String, unique, indexed | да | URL-идентификатор бизнеса (например, `7001234567`) | - |
| `name` | String | да | Название бизнеса | - |
| `phone` | String | нет | Телефон бизнеса | да |
| `email` | String | нет | Email бизнеса | да |
| `address` | String | нет | Адрес (строка из 2GIS suggest) | - |
| `city` | String | нет | Город | - |
| `description` | Text | нет | Описание бизнеса | - |
| `telegram_chat_id` | String | нет | Chat ID для Telegram уведомлений | - |
| `created_at` | DateTime | да | Дата создания (server_default=now) | - |
| `updated_at` | DateTime | да | Дата обновления (onupdate=now) | - |

**Связи:**
- `users` -> User (one-to-many)
- `services` -> Service (one-to-many)
- `masters` -> Master (one-to-many)
- `categories` -> Category (one-to-many)
- `schedules` -> Schedule (one-to-many, where master_id IS NULL)
- `bookings` -> Booking (one-to-many)

---

## User

> Таблица: `users`

| Поле | Тип | Обязательное | Описание | PII |
|------|-----|:---:|----------|:---:|
| `id` | Integer (PK) | да | Auto-increment ID | - |
| `email` | String, unique, indexed | да | Email (или placeholder `tg_{id}@telegram.mini.app`) | да |
| `password_hash` | String | да | bcrypt hash (пустой для Telegram-only users) | - |
| `full_name` | String | нет | Полное имя | да |
| `telegram_id` | String, unique | нет | Telegram user ID | да |
| `role` | String (Enum) | да | Роль: `OWNER`, `ADMIN`, `STAFF`, `CUSTOMER` | - |
| `business_id` | Integer (FK -> businesses.id) | нет | Привязка к бизнесу | - |
| `created_at` | DateTime | да | Дата создания | - |
| `updated_at` | DateTime | да | Дата обновления | - |

**Роли:**
- `OWNER` - владелец бизнеса (не используется отдельно от ADMIN)
- `ADMIN` - администратор (создается при регистрации)
- `STAFF` - сотрудник
- `CUSTOMER` - клиент (создается при Telegram auth)

---

## Category

> Таблица: `categories`

| Поле | Тип | Обязательное | Описание | PII |
|------|-----|:---:|----------|:---:|
| `id` | Integer (PK) | да | Auto-increment ID | - |
| `name` | String | да | Название категории | - |
| `business_id` | Integer (FK -> businesses.id) | да | Привязка к бизнесу | - |

**Связи:**
- `services` -> Service (one-to-many)

---

## Service

> Таблица: `services`

| Поле | Тип | Обязательное | Описание | PII |
|------|-----|:---:|----------|:---:|
| `id` | Integer (PK) | да | Auto-increment ID | - |
| `name` | String | да | Название услуги | - |
| `description` | Text | нет | Описание услуги | - |
| `duration` | Integer | да | Длительность в минутах (min=1, default=30) | - |
| `price` | Float | да | Цена в тенге (default=0) | - |
| `business_id` | Integer (FK -> businesses.id) | да | Привязка к бизнесу | - |
| `category_id` | Integer (FK -> categories.id) | нет | Привязка к категории | - |
| `is_active` | Boolean | да | Активна ли услуга (default=True) | - |

**Связи:**
- `masters` -> Master (many-to-many через `master_services`)
- `category` -> Category (many-to-one)
- `bookings` -> Booking (one-to-many)

---

## Master

> Таблица: `masters`

| Поле | Тип | Обязательное | Описание | PII |
|------|-----|:---:|----------|:---:|
| `id` | Integer (PK) | да | Auto-increment ID | - |
| `name` | String | да | Имя мастера | да |
| `business_id` | Integer (FK -> businesses.id) | да | Привязка к бизнесу | - |
| `is_active` | Boolean | да | Активен ли мастер (default=True) | - |

**Связи:**
- `services` -> Service (many-to-many через `master_services`)
- `schedules` -> Schedule (one-to-many)
- `bookings` -> Booking (one-to-many)

---

## master_services (Association Table)

> Таблица: `master_services`

| Поле | Тип | Обязательное | Описание | PII |
|------|-----|:---:|----------|:---:|
| `master_id` | Integer (FK -> masters.id, PK) | да | ID мастера | - |
| `service_id` | Integer (FK -> services.id, PK) | да | ID услуги | - |

---

## Schedule

> Таблица: `schedules`

| Поле | Тип | Обязательное | Описание | PII |
|------|-----|:---:|----------|:---:|
| `id` | Integer (PK) | да | Auto-increment ID | - |
| `business_id` | Integer (FK -> businesses.id) | да | Привязка к бизнесу | - |
| `master_id` | Integer (FK -> masters.id) | нет | NULL = расписание бизнеса, NOT NULL = расписание мастера | - |
| `day_of_week` | Integer | да | День недели: 0=Понедельник, 6=Воскресенье | - |
| `start_time` | String | да | Начало рабочего дня (формат "HH:MM") | - |
| `end_time` | String | да | Конец рабочего дня (формат "HH:MM") | - |
| `break_start_time` | String | нет | Начало перерыва (формат "HH:MM") | - |
| `break_end_time` | String | нет | Конец перерыва (формат "HH:MM") | - |
| `is_active` | Boolean | да | Рабочий ли день (default=True) | - |

**Бизнес-логика:**
- Двухуровневая система: Master schedule (если есть) > Business schedule (fallback)
- При регистрации создается 7 записей (Пн-Пт: 09:00-18:00 active, Сб-Вс: inactive)

---

## Booking

> Таблица: `bookings`

| Поле | Тип | Обязательное | Описание | PII |
|------|-----|:---:|----------|:---:|
| `id` | Integer (PK) | да | Auto-increment ID | - |
| `business_id` | Integer (FK -> businesses.id) | да | Привязка к бизнесу | - |
| `service_id` | Integer (FK -> services.id) | да | Выбранная услуга | - |
| `master_id` | Integer (FK -> masters.id) | нет | Назначенный мастер (auto-assign если не выбран) | - |
| `client_id` | Integer (FK -> clients.id) | нет | Привязка к клиенту (upsert по телефону) | - |
| `first_name` | String | да | Имя клиента (денормализовано) | да |
| `phone` | String | да | Телефон клиента (денормализовано) | да |
| `notes` | Text | нет | Комментарий клиента | - |
| `start_at` | DateTime | да | Дата и время начала записи | - |
| `end_at` | DateTime | да | Дата и время окончания (start_at + service.duration) | - |
| `status` | String (Enum) | да | Статус: `pending`, `confirmed`, `cancelled`, `completed`, `rejected` | - |
| `price_snapshot` | Float | нет | Цена на момент записи (snapshot из service.price) | - |
| `created_at` | DateTime | да | Дата создания | - |
| `updated_at` | DateTime | да | Дата обновления | - |

**Статусы:**

```
pending -> confirmed -> completed
   |           |
   v           v
rejected   cancelled
```

---

## Client

> Таблица: `clients`

| Поле | Тип | Обязательное | Описание | PII |
|------|-----|:---:|----------|:---:|
| `id` | Integer (PK) | да | Auto-increment ID | - |
| `business_id` | Integer (FK -> businesses.id) | да | Привязка к бизнесу | - |
| `first_name` | String | да | Имя клиента | да |
| `phone` | String | да | Телефон клиента (уникален в рамках бизнеса) | да |
| `created_at` | DateTime | да | Дата создания | - |

**Бизнес-логика:**
- Upsert по (business_id, phone) при создании бронирования
- Имя обновляется при каждом бронировании

---

## RescheduleProposal

> Таблица: `reschedule_proposals`

| Поле | Тип | Обязательное | Описание | PII |
|------|-----|:---:|----------|:---:|
| `id` | Integer (PK) | да | Auto-increment ID | - |
| `booking_id` | Integer (FK -> bookings.id) | да | Привязка к бронированию | - |
| `proposed_date` | Date | да | Предложенная новая дата | - |
| `proposed_time` | String | да | Предложенное новое время (формат "HH:MM") | - |
| `old_date` | Date | да | Оригинальная дата (для отката) | - |
| `old_time` | String | да | Оригинальное время | - |
| `status` | String (Enum) | да | `PENDING`, `ACCEPTED`, `DECLINED`, `EXPIRED` | - |
| `created_at` | DateTime | да | Дата создания | - |

**Бизнес-логика:**
- Lazy expiration: статус EXPIRED проставляется при GET, не по cron
- При ACCEPTED: обновляется `booking.start_at` и `booking.end_at`
- При DECLINED: бронирование остается без изменений

---

## Subscription

> Таблица: `subscriptions`

| Поле | Тип | Обязательное | Описание | PII |
|------|-----|:---:|----------|:---:|
| `id` | Integer (PK) | да | Auto-increment ID | - |
| `context_type` | Enum | да | Тип контекста подписки | - |
| `context_ref` | String | да | Ссылка на контекст (business_id, phone, booking_id) | да* |
| `channel` | Enum | да | Канал: `TELEGRAM`, `WHATSAPP`, `SMS` | - |
| `telegram_chat_id` | String | нет | Telegram chat ID (для канала TELEGRAM) | - |
| `is_active` | Boolean | да | Активна ли подписка (default=True) | - |
| `created_at` | DateTime | да | Дата создания | - |

**Context Types:**

| Тип | context_ref содержит | Назначение |
|-----|---------------------|-----------|
| `PROVIDER_BUSINESS` | business_id (int as string) | Уведомления провайдера о новых записях |
| `CLIENT_PHONE` | Телефон клиента | Уведомления клиента по телефону |
| `CLIENT_BOOKING` | booking_id (int as string) | Уведомления клиента о конкретной записи |

*`context_ref` помечен PII т.к. может содержать телефон (CLIENT_PHONE)

**Каналы:**
- `TELEGRAM` - единственный реально используемый
- `WHATSAPP`, `SMS` - определены в enum, но не реализованы

---

## ER-диаграмма (упрощенная)

```kroki-plantuml
@startuml
skinparam backgroundColor #1e293b
skinparam shadowing false
skinparam defaultFontName Inter
skinparam defaultFontColor #f8fafc
skinparam EntityBackgroundColor #F7FAFC
skinparam EntityBorderColor #2c7a7b
skinparam ArrowColor #2c7a7b

entity "Business" as b
entity "User" as u
entity "Category" as cat
entity "Service" as svc
entity "Master" as master
entity "Schedule\n(business-level)" as sch_b
entity "Schedule\n(master-level)" as sch_m
entity "Client" as cli
entity "Booking" as bkg
entity "RescheduleProposal" as rsp
entity "Subscription" as sub

b ||--o{ u : "1 : N"
b ||--o{ cat : "1 : N"
cat ||--o{ svc : "1 : N"
svc }o--o{ master : "N : N"
b ||--o{ sch_b : "1 : N"
master ||--o{ sch_m : "1 : N"
b ||--o{ cli : "1 : N"
b ||--o{ bkg : "1 : N"
bkg ||--o{ rsp : "1 : N"
bkg ||--o{ sub : "1 : N (polymorphic)"
@enduml
```

---

## PII Summary

| Сущность | PII поля | Основание |
|----------|----------|-----------|
| Business | phone, email | Контактные данные бизнеса |
| User | email, full_name, telegram_id | Персональные данные пользователя |
| Master | name | Имя физического лица |
| Booking | first_name, phone | Контактные данные клиента |
| Client | first_name, phone | Контактные данные клиента |
| Subscription | context_ref (при CLIENT_PHONE) | Телефон клиента |

---

## Типы данных (PostgreSQL mapping)

| SQLAlchemy Type | PostgreSQL Type | Используется в |
|----------------|-----------------|---------------|
| Integer | integer / serial | Все PK, FK |
| String | varchar | Большинство текстовых полей |
| Text | text | description, notes |
| Float | double precision | price, price_snapshot |
| Boolean | boolean | is_active |
| DateTime | timestamp without time zone | created_at, updated_at, start_at, end_at |
| Date | date | proposed_date, old_date |
| Enum (Python) | varchar (хранится как строка) | role, status, context_type, channel |
