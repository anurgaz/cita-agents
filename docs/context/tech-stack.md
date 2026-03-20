# Tech Stack

> ADR-light: что выбрано, версия, почему (если понятно из кода/контекста).
> Источник: recon-report.md + анализ кода.

---

## Frontend (основной SPA)

| Технология | Версия | Назначение | Почему выбрано |
|---|---|---|---|
| React | 19.2 | UI framework | Стандарт индустрии, большая экосистема |
| TypeScript | ~5.x | Типизация | Безопасность типов, IDE support |
| Vite | 6.3 | Bundler + dev server | Быстрый HMR, нативный ESM |
| Tailwind CSS | 4.1 | Utility-first CSS | Быстрая верстка, консистентный дизайн |
| shadcn/ui (Radix) | — | UI компоненты (~40 шт) | Accessible, composable, не vendor lock-in |
| react-router-dom | 7.12 | SPA routing | Стандарт для React SPA |
| i18next | 25.8 | Интернационализация | Поддержка ru + kk (казахский), необходима для KZ рынка |
| recharts | 2.15 | Графики | Аналитика провайдера |
| react-hook-form | 7.55 | Формы | Производительность (uncontrolled), валидация |
| date-fns | 3.6 | Работа с датами | Легковесная альтернатива moment.js |
| qrcode.react | 4.2 | QR-коды | Генерация QR для ссылки на запись |
| react-google-recaptcha-v3 | 1.11 | Anti-spam | Защита публичных форм |
| lucide-react | 0.487 | Иконки | Tree-shakeable, замена heroicons |
| react-helmet-async | 2.0 | SEO meta-теги | SSR-ready head management |
| motion (framer-motion) | 12.23 | Анимации | Плавные переходы в UI |

## Frontend (Telegram Mini App)

| Технология | Версия | Назначение | Почему выбрано |
|---|---|---|---|
| Next.js | 16.1 | SSR framework | Server components, app router |
| React | 19.2 | UI | Единый стек с основным SPA |
| Zustand | 5.0 | State management | Минималистичный, без boilerplate |
| Axios | 1.13 | HTTP client | Interceptors для JWT |
| Tailwind CSS | 4 | Стили | Консистентность с основным SPA |

## Backend (FastAPI)

| Технология | Версия | Назначение | Почему выбрано |
|---|---|---|---|
| Python | 3.11 | Runtime | async/await, type hints, широкая экосистема |
| FastAPI | latest | Web framework | Async, автогенерация OpenAPI, Pydantic интеграция |
| SQLAlchemy | 2.0 (async) | ORM | Mapped columns, async session, mature |
| asyncpg | — | PostgreSQL async driver | Высокая производительность для async |
| Alembic | — | Миграции БД | Стандарт для SQLAlchemy |
| Pydantic | v2 | Validation + Settings | Нативная интеграция с FastAPI, BaseSettings |
| httpx | 0.28 | HTTP client | Async, замена requests |
| PyJWT | — | JWT tokens | HS256, access tokens |
| passlib (bcrypt) | — | Password hashing | Индустриальный стандарт |
| Pillow + qrcode | — | QR генерация | Server-side QR с текстом |
| clickhouse-connect | — | ClickHouse client | Нативный HTTP клиент |
| uvicorn | — | ASGI server | Production-grade, uvloop |

**Решение о миграции с Node.js на FastAPI:**
Проект начинался на Node.js + Express + Prisma (см. \_archived/backend\_nodejs/).
Миграция на FastAPI произошла для: async-first подход, Pydantic validation,
автогенерация OpenAPI, лучшая типизация с Python type hints.

## Базы данных

| БД | Версия | Назначение | Почему выбрано |
|---|---|---|---|
| PostgreSQL | 16 Alpine | Основная OLTP БД | Надёжность, JSON, full-text search |
| ClickHouse | 24.3 Alpine | Аналитика (OLAP) | Быстрые агрегации по bookings для dashboard провайдера |

**PostgreSQL schema (основные таблицы):**
businesses, users, categories, services, masters, master\_services\_association (M2M),
schedules, bookings, clients, reschedule\_proposals, subscriptions, accounts.

**ClickHouse:**
Таблица cita\_pg.bookings — предположительно PostgreSQL engine или materialized view.
Используется только для read-only аналитики (revenue, bookings\_count, clients\_count, daily chart).
Fallback: если ClickHouse недоступен, аналитика возвращает нули.

## Инфраструктура

| Компонент | Технология | Конфигурация |
|---|---|---|
| VPS | Hetzner | 159.69.28.60 |
| OS | Linux | — |
| Контейнеризация | Docker + Docker Compose | 3 контейнера: backend, db, clickhouse |
| Reverse proxy | Nginx | SSL termination, SPA fallback, API proxy |
| SSL | Let's Encrypt (certbot) | Auto-renewal, managed by Certbot |
| Домен | cita.kz | DNS → 159.69.28.60 |
| Frontend hosting | Nginx static | /var/www/cita/dist/ |
| API proxy | Nginx | /api/ → localhost:8000 |

**Nginx конфигурация (ключевое):**
- Gzip: включён (text, css, js, json, svg, xml)
- Security headers: X-Frame-Options, X-Content-Type-Options, CSP, Referrer-Policy
- Static caching: /assets/ и /fonts/ — 365d immutable
- SPA: try\_files \ \/ /index.html

## Внешние интеграции

| Сервис | API | Назначение | Ключ/конфиг |
|---|---|---|---|
| Telegram Bot API | HTTPS REST | Уведомления (inline buttons), webhook | BOT\_TOKEN в .env, бот: @citakz\_bot |
| Telegram WebApp | JS SDK + HMAC | Mini App аутентификация | initData validation |
| 2GIS Suggest API | HTTPS REST | Автокомплит городов и адресов (KZ) | API\_KEY в config.py |
| Google reCAPTCHA v3 | HTTPS REST | Anti-spam на публичных формах | SITE\_KEY (frontend) + SECRET\_KEY (backend) |

## CI/CD

| Компонент | Статус | Примечание |
|---|---|---|
| GitHub Actions | Есть GITHUB\_ACTIONS\_SETUP.md | Не проверялся в рамках recon |
| Деплой | Ручной | git pull + docker compose up --build + vite build |
| Миграции | Автоматические при старте | CMD: alembic upgrade head && uvicorn |
| Тесты | Есть структура | src/__tests__/, backend/tests/ — покрытие не проверялось |

## Архитектурные решения

### Монолит, не микросервисы
Один FastAPI app обслуживает всё: auth, bookings, notifications, analytics.
Для текущего масштаба (один VPS, Казахстан) — оправданно.

### Async everywhere
Backend полностью async: asyncpg, httpx, SQLAlchemy async session.
Позволяет обрабатывать Telegram webhook + API запросы эффективно.

### Slug-based multitenancy
Каждый бизнес идентифицируется по slug в URL.
Все данные изолированы по business\_id (row-level filtering, не schema isolation).

### Двухуровневое расписание
Business schedule (дефолт) + Master schedule (override).
Простая модель, покрывает 95% кейсов салонов красоты.

### Lazy expiration
RescheduleProposal не имеет cron-job для expiration.
Статус EXPIRED проставляется при GET-запросе (lazy check).
Плюс: нет фонового процесса. Минус: proposal может висеть до первого GET.
