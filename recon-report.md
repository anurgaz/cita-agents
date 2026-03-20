# Cita.kz — Reconnaissance Report

> Дата: 2026-03-20
> Репозиторий: https://github.com/anurgaz/cita
> Production: https://cita.kz
> VPS: 159.69.28.60

---

## 1. Структура проекта

```
cita/
├── src/                          # Frontend (React SPA) — основное веб-приложение
│   ├── app/
│   │   ├── App.tsx               # Router: /, /hey, /register, /superadmin, /my/:slug, /:slug
│   │   ├── pages/
│   │   │   ├── BookingPage.tsx   # Страница записи клиента (/:slug)
│   │   │   ├── AdminPage.tsx     # Админ-панель провайдера (/my/:slug)
│   │   │   ├── SuperAdminPage.tsx # Суперадмин (/superadmin)
│   │   │   ├── LandingPage.tsx   # Лендинг (/hey)
│   │   │   └── RegistrationPage.tsx # Регистрация бизнеса (/register)
│   │   └── components/
│   │       ├── admin/            # Компоненты админки (dashboard, settings, analytics, catalog, clients)
│   │       ├── superadmin/       # SuperAdminDashboard, SuperAdminLogin
│   │       ├── common/           # AddressAutocomplete, CityAutocomplete, QRCodeBlock
│   │       ├── figma/            # LandingPage (Figma export)
│   │       ├── ui/               # ~40 shadcn/ui компонентов (Radix-based)
│   │       ├── DateTimeStep.tsx  # Шаг бронирования: выбор даты/времени
│   │       ├── ServiceSelectionStep.tsx
│   │       ├── CustomerInfoStep.tsx
│   │       ├── ConfirmationStep.tsx
│   │       ├── MasterDateTimeStep.tsx
│   │       └── MasterServiceStep.tsx
│   ├── services/api.ts           # Axios client (baseURL: /api/v1)
│   ├── contexts/LanguageContext.tsx
│   ├── hooks/useTranslation.ts
│   ├── locales/                  # i18n: ru, kk (казахский)
│   │   ├── ru/{admin,booking,common,landing,meta,registration,validation}.json
│   │   └── kk/{admin,booking,common,landing,meta,registration,validation}.json
│   └── utils/                    # analytics.ts, clientStorage.ts, phone.ts
│
├── backend/                      # Backend (FastAPI, Python 3.11)
│   ├── app/
│   │   ├── main.py               # FastAPI app, CORS, router mount
│   │   ├── core/
│   │   │   ├── config.py         # Pydantic Settings (DB, JWT, Telegram, 2GIS, reCAPTCHA, ClickHouse)
│   │   │   └── security.py       # JWT (HS256), bcrypt password hashing
│   │   ├── db/session.py         # AsyncSession (asyncpg)
│   │   ├── models/               # SQLAlchemy 2.0 models
│   │   │   ├── auth.py           # Business, User
│   │   │   ├── catalog.py        # Category, Service, Master, Schedule, master_services (M2M)
│   │   │   ├── booking.py        # Booking, Client, RescheduleProposal
│   │   │   └── notification.py   # Subscription (Telegram notifications)
│   │   ├── schemas/              # Pydantic v2 response/request schemas
│   │   ├── api/
│   │   │   ├── deps.py           # get_current_user dependency (JWT → User)
│   │   │   └── v1/
│   │   │       ├── api.py        # Router aggregator (13 sub-routers)
│   │   │       └── endpoints/
│   │   │           ├── auth.py           # login, register, telegram auth, reset-password
│   │   │           ├── public.py         # GET /{slug}, /{slug}/slots, POST /{slug}/booking
│   │   │           ├── bookings.py       # CRUD записей (auth required)
│   │   │           ├── services.py       # CRUD услуг (auth required)
│   │   │           ├── masters.py        # CRUD мастеров (auth required)
│   │   │           ├── categories.py     # CRUD категорий
│   │   │           ├── schedule.py       # CRUD расписания (бизнес + мастер)
│   │   │           ├── business.py       # GET/PUT бизнеса
│   │   │           ├── analytics.py      # ClickHouse analytics (revenue, chart)
│   │   │           ├── location.py       # 2GIS: поиск городов и адресов
│   │   │           ├── telegram_webhook.py # Webhook handler
│   │   │           ├── reschedule.py     # Reschedule proposals (CRUD + notify)
│   │   │           └── superadmin.py     # Platform admin (CRUD businesses, bookings, stats, seed-demo)
│   │   └── services/
│   │       ├── availability.py    # Slot calculation (per-master, aggregated)
│   │       ├── notification.py    # Telegram notifications (new booking, status change, reschedule)
│   │       ├── telegram_bot.py    # httpx → Telegram Bot API (send, edit, callback, photo)
│   │       ├── telegram_handler.py # Deep links, /start, callback_query (confirm/reject/reschedule)
│   │       ├── qr_service.py      # QR code generation (PIL + qrcode)
│   │       └── recaptcha.py       # Google reCAPTCHA v3 verification
│   ├── alembic/                   # Database migrations
│   ├── scripts/                   # seed_demo_data.py
│   ├── Dockerfile                 # Multi-stage: python:3.11-slim-bookworm, venv, non-root user
│   ├── docker-compose.yml         # Dev: backend + db + clickhouse
│   └── pyproject.toml
│
├── mini-app/                     # Telegram Mini App (Next.js 16 + Zustand)
│   ├── src/app/
│   │   ├── customer/             # /customer, /customer/booking, /customer/my
│   │   ├── provider/             # /provider
│   │   └── admin/                # /admin
│   ├── src/hooks/useTelegram.ts
│   ├── src/lib/telegram.ts
│   ├── src/services/api.ts       # Axios (baseURL: /api/v1)
│   └── src/store/auth.ts         # Zustand auth store
│
├── landing page/                 # Отдельный лендинг (Vite + React, экспорт из Figma)
│
├── _archived/backend_nodejs/     # Legacy Node.js/Express/Prisma backend (deprecated)
│
├── docker-compose.yml            # Prod: backend + db (no ClickHouse)
├── nginx-config.conf
│
└── *.md                          # Документация (см. раздел 3)
```

## 2. Стек технологий

### Frontend (основной — `src/`)
| Технология | Версия | Назначение |
|---|---|---|
| React | 19.2 | UI framework |
| Vite | 6.3 | Bundler |
| TypeScript | - | Типизация |
| Tailwind CSS | 4.1 | Стили |
| shadcn/ui (Radix) | - | UI компоненты (~40 шт) |
| react-router-dom | 7.12 | SPA routing |
| i18next + react-i18next | 25.8 | Интернационализация (ru, kk) |
| recharts | 2.15 | Графики в аналитике |
| qrcode.react | 4.2 | QR-коды |
| react-google-recaptcha-v3 | 1.11 | reCAPTCHA |
| date-fns | 3.6 | Работа с датами |
| react-hook-form | 7.55 | Формы |
| react-helmet-async | 2.0 | SEO мета-теги |
| lucide-react | 0.487 | Иконки |

### Frontend (mini-app — `mini-app/`)
| Технология | Версия | Назначение |
|---|---|---|
| Next.js | 16.1 | SSR framework |
| React | 19.2 | UI |
| Zustand | 5.0 | State management |
| Axios | 1.13 | HTTP client |
| Tailwind CSS | 4 | Стили |

### Backend (FastAPI — `backend/`)
| Технология | Версия | Назначение |
|---|---|---|
| Python | 3.11 | Runtime |
| FastAPI | latest | Web framework |
| SQLAlchemy | 2.0 (async) | ORM |
| asyncpg | - | PostgreSQL async driver |
| Alembic | - | Миграции |
| Pydantic | v2 | Validation/Settings |
| httpx | 0.28 | HTTP client (Telegram API, reCAPTCHA, 2GIS) |
| PyJWT | - | JWT tokens |
| bcrypt/passlib | - | Password hashing |
| qrcode + Pillow | - | QR generation |
| clickhouse-connect | - | ClickHouse client |
| uvicorn | - | ASGI server |

### Инфраструктура
| Компонент | Технология |
|---|---|
| СУБД (основная) | PostgreSQL 16 Alpine |
| СУБД (аналитика) | ClickHouse 24.3 Alpine |
| Контейнеризация | Docker + Docker Compose |
| Reverse proxy | Nginx + Let's Encrypt (certbot) |
| VPS | Hetzner 159.69.28.60 |
| DNS | cita.kz |
| Домен фронтенда | /var/www/cita/dist (статика через Nginx) |
| API proxy | Nginx → localhost:8000 |

### Архитектура (legacy)
Есть `_archived/backend_nodejs/` — старый Node.js + Express + Prisma бэкенд. Он заменён FastAPI. В документации ещё встречаются упоминания Prisma и Node.

---

## 3. Документация (.md файлы)

| Файл | Содержимое | Актуальность |
|---|---|---|
| `README.md` | Заглушка от Figma ("Создать макет из скриншотов") | ⚠️ Не обновлён |
| `API.md` | Описание эндпоинтов (базовое, только основные) | ⚠️ Устарел — описывает Node.js бэкенд (port 3001), не FastAPI |
| `DEPLOYMENT.md` | Локальное развертывание (Docker, npm, Prisma) | ⚠️ Устарел — описывает Node.js стек |
| `DEPLOY_TO_SERVER.md` | Деплой на 159.69.28.60 (FastAPI + Nginx + SSL) | ✅ Актуален |
| `SECURITY_ANALYSIS.md` | Анализ безопасности (от 2026-02-03) | ⚠️ Описывает Express backend |
| `ANALYTICS_SETUP.md` | Настройка ClickHouse аналитики | ✅ Актуален |
| `GITHUB_ACTIONS_SETUP.md` | CI/CD через GitHub Actions | ❓ Не проверялось |
| `GOOGLE_ANALYTICS_SETUP.md` | GA интеграция | ❓ |
| `INTEGRATION_PLAN.md` | План интеграции Telegram + WhatsApp | ❓ |
| `PRODUCTION_SEED_GUIDE.md` | Как заполнить демо-данные | ✅ |
| `ATTRIBUTIONS.md` | Лицензии | — |
| `guidelines/Guidelines.md` | Пустой шаблон (без реальных гайдлайнов) | ❌ Не заполнен |
| `backend/QUICK_START_SEED.md` | Быстрый старт сида | ✅ |
| `backend/SEED_README.md` | Документация seed скрипта | ✅ |

---

## 4. API Эндпоинты (FastAPI, актуальные)

Все под префиксом `/api/v1`.

### Auth (`/api/v1/auth/`)
| Метод | Путь | Auth | Описание |
|---|---|---|---|
| POST | `/login` | - | Логин (email + password → JWT) |
| POST | `/register` | - | Регистрация бизнеса (создает Business + User + Services + Masters + Categories + Schedule) |
| POST | `/telegram` | - | Аутентификация через Telegram WebApp initData (HMAC-SHA256) |
| POST | `/reset-password` | - | Сброс пароля по телефону → Telegram |

### Public (`/api/v1/public/`)
| Метод | Путь | Auth | Описание |
|---|---|---|---|
| GET | `/{slug}` | - | Полная инфо о бизнесе (services, masters, categories) |
| GET | `/{slug}/services` | - | Список услуг бизнеса |
| GET | `/{slug}/masters` | - | Список мастеров бизнеса |
| GET | `/{slug}/schedule` | - | Расписание (бизнес или мастер) |
| GET | `/{slug}/slots?date=&master_id=` | - | Рабочие часы + busy intervals |
| POST | `/{slug}/booking` | - | Создание записи (reCAPTCHA) |
| GET | `/booking/{booking_id}` | - | Статус записи (polling) |
| GET | `/my-bookings?telegram_id=` | - | Записи клиента по Telegram ID |

### Services (`/api/v1/services/`) — JWT required
| Метод | Путь | Описание |
|---|---|---|
| GET | `/` | Список услуг бизнеса |
| POST | `/` | Создание услуги |
| PUT | `/{id}` | Обновление услуги |
| DELETE | `/{id}` | Удаление услуги |

### Masters (`/api/v1/masters/`) — JWT required
| Метод | Путь | Описание |
|---|---|---|
| GET | `/` | Список мастеров |
| POST | `/` | Создание мастера (+ привязка услуг) |
| PUT | `/{id}` | Обновление мастера |
| DELETE | `/{id}` | Удаление мастера |

### Bookings (`/api/v1/bookings/`) — JWT required
| Метод | Путь | Описание |
|---|---|---|
| GET | `/` | Все записи бизнеса |
| GET | `/{id}` | Запись по ID |
| PATCH | `/{id}` | Обновление статуса (+ notification клиенту) |
| DELETE | `/{id}` | Удаление (+ notification «cancelled») |

### Categories (`/api/v1/categories/`) — JWT required
| Метод | Путь | Описание |
|---|---|---|
| GET | `/` | Список категорий |
| POST | `/` | Создание |
| PUT | `/{id}` | Обновление |
| DELETE | `/{id}` | Удаление |

### Schedule (`/api/v1/schedule/`) — JWT required
| Метод | Путь | Описание |
|---|---|---|
| GET | `/?masterId=` | Расписание (бизнес или мастер) |
| POST | `/master/{master_id}` | Создать дефолтное расписание мастера (7 дней) |
| PUT | `/{id}` | Обновить день расписания |
| DELETE | `/master/{master_id}` | Удалить расписание мастера |

### Business (`/api/v1/business/`) — JWT required
| Метод | Путь | Описание |
|---|---|---|
| GET | `/` | Инфо о своём бизнесе |
| PUT | `/` | Обновление (slug, name, phone, email, address) |

### Analytics (`/api/v1/analytics/`) — JWT required
| Метод | Путь | Описание |
|---|---|---|
| GET | `/{slug}?period=week\|month\|year` | Revenue, bookings, clients, chart (ClickHouse) |

### Location (`/api/v1/location/`)
| Метод | Путь | Auth | Описание |
|---|---|---|---|
| GET | `/cities?q=` | - | Поиск городов (2GIS Suggest API, фильтр KZ) |
| GET | `/addresses?q=&lat=&lon=` | - | Поиск адресов (2GIS, сортировка по proximity) |

### Telegram (`/api/v1/telegram/`)
| Метод | Путь | Описание |
|---|---|---|
| POST | `/webhook` | Telegram Bot webhook handler |

### Reschedule (`/api/v1/reschedule/`) — JWT required
| Метод | Путь | Описание |
|---|---|---|
| POST | `/{booking_id}` | Создать предложение переноса (→ notify клиента) |
| GET | `/{booking_id}` | Список предложений переноса |

### SuperAdmin (`/api/v1/superadmin/`) — SuperAdmin JWT required
| Метод | Путь | Описание |
|---|---|---|
| POST | `/login` | Логин суперадмина |
| GET | `/businesses` | Список всех бизнесов (pagination, search) |
| GET | `/businesses/{id}` | Детали бизнеса |
| PUT | `/businesses/{id}` | Обновление бизнеса |
| DELETE | `/businesses/{id}` | Удаление бизнеса (cascade) |
| GET | `/bookings` | Все записи (pagination, filter) |
| GET | `/bookings/{id}` | Детали записи |
| PATCH | `/bookings/{id}` | Обновление статуса |
| DELETE | `/bookings/{id}` | Удаление записи |
| GET | `/stats` | Платформенная статистика |
| POST | `/seed-demo` | Заполнение демо-данных |
| POST | `/businesses/{id}/reset-password` | Сброс пароля провайдера |
| POST | `/add-master` | Добавление мастера в бизнес |
| POST | `/fix-schedule` | Исправление расписания |

---

## 5. Деплой

### Текущая production-конфигурация

```
Internet → cita.kz → Nginx (SSL, Let's Encrypt)
                        ├── / → /var/www/cita/dist (React SPA статика)
                        └── /api/ → localhost:8000 (FastAPI в Docker)

Docker containers:
  cita-backend-v2-backend-1   → FastAPI app (port 8000)
  cita-backend-v2-db-1        → PostgreSQL 16
  cita-backend-v2-clickhouse-1 → ClickHouse 24.3 (ports 8124, 9001)
```

### Docker Compose (prod — `docker-compose.yml` в корне)
- `db`: PostgreSQL 16 Alpine, volume `postgres_data`, healthcheck, порт 5433 (только localhost)
- `backend`: FastAPI, зависит от db, порт 8000, env_file из `backend/.env`

### Docker Compose (backend dev — `backend/docker-compose.yml`)
- Добавлен ClickHouse (8124:8123, 9001:9000)

### Dockerfile (backend/)
- Multi-stage build: `python:3.11-slim-bookworm`
- Устанавливает зависимости в venv
- Non-root user `appuser`
- CMD: `alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000`

### Nginx
- SSL: Let's Encrypt (certbot managed)
- Gzip: включён для text/css/js/json/svg/xml
- Security headers: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, CSP, Referrer-Policy
- SPA fallback: `try_files $uri $uri/ /index.html`
- Static caching: `/assets/` 365d immutable, `/fonts/` 365d + CORS
- API proxy: `/api/` → `http://localhost:8000`

### Деплой фронтенда
- `vite build` → `dist/`
- Копируется на сервер: `/var/www/cita/dist/`
- Nginx раздаёт статику

---

## 6. Интеграции

### 6.1 Telegram Bot API (`@citakz_bot`)

**Подключение:** httpx → `https://api.telegram.org/bot{TOKEN}/...`

**Используемые методы:**
- `sendMessage` (с inline_keyboard)
- `editMessageText`
- `answerCallbackQuery`
- `sendPhoto` (QR-коды)

**Бот-сценарии:**

**Для провайдеров (владельцев бизнеса):**
1. Провайдер нажимает "Уведомления в Telegram" в админке
2. Deep link: `https://t.me/citakz_bot?start=provider_{business_id}`
3. Бот создаёт Subscription (PROVIDER_BUSINESS)
4. При новой записи → бот отправляет сообщение с inline-кнопками: ✅ Подтвердить / ❌ Отклонить / 🔄 Перенести
5. Callback handling: `confirm_{booking_id}`, `reject_{booking_id}`, `reschedule_{booking_id}`

**Для клиентов:**
1. После создания записи клиенту показывается ссылка "Подписаться в Telegram"
2. Deep link: `https://t.me/citakz_bot?start=client_{booking_id}`
3. Бот создаёт Subscription (CLIENT_BOOKING)
4. Бот запрашивает телефон для постоянной подписки (CLIENT_PHONE)
5. Клиент получает уведомления: подтверждение, отмена, предложение переноса

**Telegram WebApp (mini-app):**
- Аутентификация через initData + HMAC-SHA256 верификация
- Auto-создание пользователя с ролью CUSTOMER
- Deep link `?startapp={slug}` привязывает к бизнесу

**Reschedule flow через бота:**
1. Провайдер нажимает 🔄 на записи
2. Бот предлагает выбрать дату и время
3. Создаётся RescheduleProposal (PENDING, expires 24h)
4. Клиенту приходит уведомление с кнопками ra_{id} / rd_{id}
5. При ответе: обновляется пропозал + уведомление провайдеру

### 6.2 2GIS

**Подключение:** httpx → `https://catalog.api.2gis.com/3.0/`

**Используемые API:**
- **Suggests API** (`/3.0/suggests`): Поиск городов (тип `adm_div.city`, фильтр `country_id=4` Казахстан) и адресов (`suggest_type=address`, sort_point по координатам)
- API Key: `735f4a57-82a6-4eed-bad2-28e8b0f2b89d`
- Locale: `ru_KZ`

**Применение:**
- Форма регистрации: автокомплит города → автокомплит адреса (с proximity sorting)

### 6.3 Google reCAPTCHA v3
- Защита: создание записей (POST booking), регистрация бизнеса
- Frontend: `react-google-recaptcha-v3`
- Backend: `recaptcha.py` → Google verify API

### 6.4 ClickHouse
- Аналитика для провайдеров (revenue, bookings count, unique clients, daily chart)
- Таблица: `cita_pg.bookings` (видимо, настроен PostgreSQL engine/materialized view)
- Период: week/month/year
- Fallback: если ClickHouse недоступен → возвращает нули

---

## 7. Пользовательские роли

### 7.1 Модель User

| Роль | Описание | Создание |
|---|---|---|
| `OWNER` | Владелец бизнеса (зарезервировано, не используется явно) | — |
| `ADMIN` | Администратор бизнеса (полный доступ к админке) | При /register |
| `STAFF` | Сотрудник (зарезервировано) | — |
| `CUSTOMER` | Клиент (создаётся при Telegram auth) | Auto при Telegram WebApp |

### 7.2 SuperAdmin
- Отдельная аутентификация (не через User таблицу)
- Credentials в env: `SUPERADMIN_EMAIL`, `SUPERADMIN_PASSWORD`
- JWT с `isSuperAdmin: true`, 24h expiry
- Полный доступ: CRUD бизнесов, записей, seed данных, сброс паролей

### 7.3 Фактические роли в системе

**Клиент (public, без auth):**
- Просмотр бизнеса по slug
- Просмотр услуг, мастеров, расписания, слотов
- Создание записи (reCAPTCHA)
- Просмотр статуса записи
- Подписка на Telegram-уведомления
- Ответ на предложение переноса

**Провайдер/Админ (JWT auth):**
- CRUD услуг, мастеров, категорий
- Управление расписанием (бизнес-уровень + per-master)
- Управление записями (подтверждение, отклонение, удаление)
- Предложение переноса
- Просмотр аналитики (ClickHouse)
- Настройки бизнеса (name, slug, address, phone, email)
- QR-код для записи
- Telegram-уведомления

**Суперадмин:**
- Все бизнесы: просмотр, редактирование, удаление
- Все записи: просмотр, изменение статуса, удаление
- Платформенная статистика
- Seed демо-данных
- Сброс паролей провайдеров
- Добавление мастеров / исправление расписания

---

## 8. Бизнес-логика записи

### 8.1 Поток записи клиента

```
1. Клиент заходит на /{slug}
2. GET /public/{slug} → инфо бизнеса
3. GET /public/{slug}/services → выбор услуги
4. GET /public/{slug}/masters → выбор мастера (или "любой")
5. GET /public/{slug}/slots?date=YYYY-MM-DD&master_id=xxx → слоты
6. Клиент выбирает дату + время, вводит имя + телефон
7. POST /public/{slug}/booking → создание записи
8. Запись создаётся со статусом "pending"
9. Провайдеру → Telegram: кнопки ✅/❌/🔄
10. Клиент видит "Подписаться в Telegram" + ссылку
11. Клиент может поллить GET /public/booking/{id} для обновлений
```

### 8.2 Слоты и расписание

**Schedule модель:**
- 7 записей на каждый день недели (0=Mon, 6=Sun)
- Поля: `start_time`, `end_time`, `break_start_time`, `break_end_time`, `is_active`
- Уровни: бизнес-расписание (`master_id=NULL`) и мастер-расписание
- Приоритет: мастер > бизнес

**Расчёт слотов (AvailabilityService):**
- **Per-master:** расписание дня → busy intervals (break + существующие записи) → merge overlapping
- **Aggregated (любой мастер):** minute-resolution array [0..1440], для каждого мастера: +1 рабочее время, −1 перерыв, −1 запись → intervals где `count ≤ 0` = занято

**Формат ответа:**
```json
{
  "work_start": "09:00",
  "work_end": "18:00",
  "busy_intervals": [["13:00", "14:00"], ["15:00", "15:30"]]
}
```

### 8.3 Статусы записи

```
pending → confirmed → completed
        → cancelled
        → rejected
```

- `pending`: создана клиентом, ждёт подтверждения провайдера
- `confirmed`: подтверждена провайдером (через веб или Telegram)
- `cancelled`: отменена (провайдером или при удалении)
- `rejected`: отклонена провайдером
- `completed`: завершена

### 8.4 Перенос (Reschedule)

```
1. Провайдер создаёт RescheduleProposal (POST /reschedule/{booking_id})
2. Status: PENDING, expires 24h
3. Клиенту → Telegram: новое время + кнопки ✅/❌
4. Клиент принимает → booking.start_at обновляется, proposal.status=ACCEPTED
5. Клиент отклоняет → proposal.status=DECLINED, запись остаётся
6. Timeout → proposal.status=EXPIRED (lazy check при GET)
```

### 8.5 Авто-назначение мастера

Если клиент не выбрал мастера (`master_id=null`):
1. Ищет мастера, привязанного к выбранной услуге (M2M `master_services`)
2. Если нет → берёт любого мастера бизнеса
3. Если мастеров нет → HTTP 400 "No masters available"

### 8.6 Клиенты

- При создании записи: ищет Client по phone + business_id
- Если не найден → создаёт нового
- Если найден → обновляет имя и дописывает notes
- Телефон нормализуется: убирается `+`, `-`, пробелы; `8` → `7` (KZ формат)

### 8.7 Напоминания

⚠️ **Автоматических напоминаний (reminder перед записью) НЕТ.** Уведомления отправляются только при:
- Новая запись → провайдеру
- Изменение статуса → клиенту
- Предложение переноса → клиенту
- Ответ на перенос → провайдеру

---

## 9. Известные проблемы и технический долг

1. **Документация устарела**: API.md, DEPLOYMENT.md описывают Node.js бэкенд, а не FastAPI
2. **README.md — заглушка** от Figma
3. **Guidelines пустые** — нет реальных гайдлайнов разработки
4. **Нет автоматических напоминаний** перед записью
5. **Нет проверки overlap** при создании записи (комментарий TODO в коде)
6. **Race condition** при создании записей (нет pessimistic locking)
7. **Timezone handling**: используется naive datetime, нет явной TZ логики
8. **Секреты в коде**: config.py содержит дефолтные TELEGRAM_BOT_TOKEN, 2GIS_API_KEY, RECAPTCHA_SECRET (должны быть только в .env)
9. **SuperAdmin auth**: пароль plain text в dev-mode, нет rate limiting (закомментировано)
10. **Нет WebSocket/SSE**: клиент поллит статус записи через GET
11. **Нет push-уведомлений**: только Telegram (нет SMS, нет email, нет web push)
12. **mini-app** выглядит как WIP — базовая структура
