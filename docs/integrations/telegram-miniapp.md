# Telegram Mini App Integration

> Источник: `mini-app/src/lib/telegram.ts`, `mini-app/src/hooks/useTelegram.ts`, `mini-app/src/store/auth.ts`, `backend/app/api/v1/endpoints/auth.py`

## Общие сведения

| Параметр | Значение |
|----------|----------|
| Фреймворк | Next.js 16 (App Router) |
| State | Zustand 5 |
| HTTP Client | Axios |
| Telegram SDK | `window.Telegram.WebApp` (встроенный JS SDK) |
| Точка входа | Deep link: `https://t.me/{bot}?startapp={slug}` |

## Архитектура взаимодействия

```
Telegram Client
    |
    v
Mini App (Next.js, iframe внутри Telegram)
    |
    | 1. window.Telegram.WebApp.initData
    | 2. POST /api/v1/auth/telegram { initData, startParam }
    v
Backend (FastAPI)
    |
    | 3. HMAC-SHA256 validation
    | 4. Find/create user
    | 5. Return JWT + role + businessSlug
    v
Mini App
    | 6. Сохранить JWT в Zustand store
    | 7. Все последующие запросы с Bearer token
    v
Public API (/api/v1/public/{slug}/...)
```

## Авторизация (initData)

### Шаг 1: Получение initData (клиент)

```typescript
// mini-app/src/lib/telegram.ts
const tg = window.Telegram?.WebApp;
const initData = tg?.initData;        // URL-encoded строка
const startParam = tg?.initDataUnsafe?.start_param;  // slug бизнеса
```

### Шаг 2: Отправка на бэкенд

```typescript
// mini-app/src/store/auth.ts
POST /api/v1/auth/telegram
Body: { initData: string, startParam: string }
```

### Шаг 3: Валидация на бэкенде

**Алгоритм HMAC-SHA256 (RFC от Telegram):**

1. Распарсить `initData` как URL query string
2. Извлечь `hash` параметр
3. Собрать `data_check_string`: все пары key=value (кроме hash), отсортированные по ключу, разделенные newline
4. Вычислить `secret_key = HMAC-SHA256("WebAppData", BOT_TOKEN)`
5. Вычислить `computed_hash = HMAC-SHA256(secret_key, data_check_string)`
6. Сравнить `computed_hash == received_hash`

**Проверка свежести:**
- `auth_date` не старше 5 минут (`timedelta(minutes=5)`)
- Используется `datetime.utcnow()` (без timezone)

### Шаг 4: Создание/поиск пользователя

| Условие | Действие |
|---------|----------|
| User с `telegram_id` найден | Вернуть существующего пользователя |
| User не найден | Создать нового с `role=CUSTOMER` |

**Новый пользователь:**
- `email`: `tg_{telegram_id}@telegram.mini.app` (placeholder)
- `password_hash`: `""` (пустой, логин только через Telegram)
- `full_name`: `first_name` из Telegram
- `business_id`: из `startParam` (slug -> Business.id), если бизнес найден
- `role`: `CUSTOMER`

### Шаг 5: Ответ

```json
{
  "token": "eyJ...",
  "role": "customer",
  "businessSlug": "salon-beauty",
  "user": {
    "id": 42,
    "name": "Ivan",
    "telegramId": "123456789"
  }
}
```

## Zustand Auth Store

```typescript
// mini-app/src/store/auth.ts
interface AuthState {
  token: string | null;
  role: string | null;
  businessSlug: string | null;
  user: { id: number; name: string; telegramId: string } | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: () => Promise<void>;  // POST /auth/telegram
  logout: () => void;          // Clear state
}
```

- `persist`: Zustand middleware для сохранения в localStorage
- `login()` автоматически берет `initData` и `startParam` из `window.Telegram.WebApp`

## Axios Interceptor

```typescript
// mini-app/src/services/api.ts
// Request: attach JWT from Zustand store
// Response: on 401 -> automatic logout()
```

## Telegram WebApp SDK Usage

### Haptic Feedback

```typescript
haptic?.impactOccurred('medium');       // При нажатии кнопки
haptic?.notificationOccurred('success'); // При успехе
haptic?.notificationOccurred('error');   // При ошибке
```

### MainButton (нижняя кнопка Telegram)

```typescript
mainButton?.setText('Записаться');
mainButton?.show();
mainButton?.onClick(callback);
mainButton?.hide();
```

### BackButton

```typescript
backButton?.show();
backButton?.onClick(callback);
backButton?.hide();
```

### Другие методы

| Метод | Использование |
|-------|--------------|
| `tg.ready()` | Сигнал Telegram что приложение загружено |
| `tg.expand()` | Развернуть Mini App на весь экран |
| `tg.close()` | Закрыть Mini App |
| `tg.themeParams` | Цвета темы Telegram (для адаптации UI) |

## Данные, передаваемые между Mini App и Backend

### От Mini App к Backend

| Endpoint | Данные | Назначение |
|----------|--------|-----------|
| `POST /auth/telegram` | `initData`, `startParam` | Авторизация |
| `GET /public/{slug}` | slug (из startParam) | Информация о бизнесе |
| `GET /public/{slug}/services` | slug | Список услуг |
| `GET /public/{slug}/masters` | slug | Список мастеров |
| `GET /public/{slug}/slots` | slug, date, master_id? | Свободные слоты |
| `POST /public/{slug}/bookings` | service_id, master_id?, date, time, first_name, phone, notes? | Создание записи |

### От Backend к Mini App

| Данные | Формат |
|--------|--------|
| Business info | `{ id, slug, name, phone, address }` |
| Services | `[{ id, name, duration, price, category }]` |
| Masters | `[{ id, name, services: [...] }]` |
| Slots | `[{ time: "09:00", available: true }]` |
| Booking result | `{ id, status, start_at, service, master }` |

## Ограничения Mini App

| Ограничение | Описание |
|-------------|----------|
| **Размер initData** | Ограничен Telegram (~4KB). Достаточно для auth |
| **Нет push** | Mini App не может отправлять push. Уведомления через бота |
| **localStorage** | Доступен, но может быть очищен Telegram |
| **Нет фоновой работы** | Mini App останавливается при сворачивании |
| **CORS** | Backend должен разрешать origin Mini App |
| **HTTPS обязателен** | Telegram требует HTTPS для Mini App URL |
| **auth_date 5 min** | initData валидна 5 минут. JWT - 8 дней |
| **Нет refresh token** | При истечении JWT нужно заново открыть Mini App |
| **Платежи** | Telegram Payments API не используется |
