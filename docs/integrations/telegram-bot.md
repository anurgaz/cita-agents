# Telegram Bot Integration

> Источник: `backend/app/services/telegram_bot.py`, `telegram_handler.py`, `api/v1/endpoints/telegram_webhook.py`

## Общие сведения

| Параметр | Значение |
|----------|----------|
| Режим | **Webhook** (не polling) |
| Endpoint | `POST /api/v1/telegram/webhook` |
| Библиотека | **httpx** (async HTTP client, не python-telegram-bot) |
| Base URL | `https://api.telegram.org/bot{TOKEN}/` |
| Токен | `settings.TELEGRAM_BOT_TOKEN` (env) |
| Формат сообщений | Markdown (`parse_mode=Markdown`) |

## Webhook Setup

```
POST /api/v1/telegram/set-webhook?url={webhook_url}
```

- Вызывает `bot.setWebhook(url=webhook_url)`
- Должен быть HTTPS URL
- Настраивается вручную через endpoint (нет auto-setup при старте)

### Debug Endpoints

| Endpoint | Назначение |
|----------|-----------|
| `GET /telegram/debug/webhook` | Показать текущий webhook (`getWebhookInfo`) |
| `GET /telegram/debug/subscription/{business_id}` | Проверить подписку бизнеса |

## Команды бота

### /start - Главная точка входа

Обрабатывает deep links через параметр после `/start`:

| Deep Link Pattern | Действие | Пример |
|-------------------|----------|--------|
| `provider_{business_id}` | Привязка провайдера (PROVIDER_BUSINESS subscription) | `/start provider_5` |
| `client_{phone}` | Привязка клиента по телефону (CLIENT_PHONE subscription) | `/start client_77001234567` |
| `subscribe_{booking_id}` | Подписка на статус брони (CLIENT_BOOKING subscription) | `/start subscribe_42` |
| (без параметра) | Приветственное сообщение | `/start` |

**Логика deep link `provider_`:**
1. Извлечь `business_id` из параметра
2. Проверить существование бизнеса в БД
3. Сохранить `telegram_chat_id` в `Business.telegram_chat_id`
4. Создать/обновить `Subscription(context_type=PROVIDER_BUSINESS, context_ref=business_id)`
5. Ответить: "Уведомления для {business.name} включены!"

**Логика deep link `client_`:**
1. Извлечь телефон из параметра
2. Создать `Subscription(context_type=CLIENT_PHONE, context_ref=phone)`
3. Ответить: "Вы подписаны на уведомления по номеру {phone}"

**Логика deep link `subscribe_`:**
1. Извлечь `booking_id`
2. Проверить существование брони
3. Создать `Subscription(context_type=CLIENT_BOOKING, context_ref=booking_id)`
4. Ответить информацию о записи

### Другие команды

| Команда | Описание |
|---------|----------|
| `/help` | Список доступных команд |
| `/unsubscribe` | Деактивация всех подписок текущего chat_id |
| `/status` | Показать активные подписки текущего chat_id |

## Callback Queries (Inline Keyboards)

### Управление бронированиями (провайдер)

| callback_data | Действие | Результат |
|---------------|----------|-----------|
| `confirm_{booking_id}` | Подтвердить запись | status -> `confirmed`, уведомление клиенту |
| `reject_{booking_id}` | Отклонить запись | status -> `rejected`, уведомление клиенту |
| `reschedule_{booking_id}` | Начать перенос | Показать выбор даты (кнопки дат) |

### Перенос записи (провайдер)

| callback_data | Действие |
|---------------|----------|
| `rh_{booking_id}_{hours}` | Выбрать час для переноса |
| `rm_{booking_id}_{date}_{hour}_{minutes}` | Выбрать минуты -> создать RescheduleProposal |

### Ответ на перенос (клиент)

| callback_data | Действие |
|---------------|----------|
| `ra_{proposal_id}` | Принять перенос (status -> ACCEPTED, обновить booking.start_at) |
| `rd_{proposal_id}` | Отклонить перенос (status -> DECLINED) |

## Формат уведомлений

### Новая заявка (провайдеру)

```
Новая заявка на запись!

Клиент: {first_name}
Телефон: {phone}
Услуга: {service.name}
Мастер: {master.name}
Дата: {DD.MM.YYYY}
Время: {HH:MM}
Цена: {price} KZT
Комментарий: {notes}

Подтвердите или отклоните запись:
[Подтвердить] [Отклонить]
[Перенести]
```

### Подтверждение записи (клиенту)

```
Запись ПОДТВЕРЖДЕНА

{business.name}
Услуга: {service.name}
Мастер: {master.name}
Дата: {DD.MM.YYYY}
Время: {HH:MM}
Адрес: {address}

Ждем вас!
```

### Отмена (клиенту)

```
Запись ОТМЕНЕНА

{business.name}
Услуга: {service.name}
Мастер: {master.name}
Дата: {DD.MM.YYYY}
Время: {HH:MM}

Свяжитесь с салоном для записи на другое время.
```

### Предложение переноса (клиенту)

```
Предложение о переносе

Мастер предлагает перенести запись:
Было: {DD.MM HH:MM}
Предложено: {DD.MM} в {HH:MM}
Услуга: {service.name}

Вам подходит это время?
[Подтвердить] [Отклонить]
```

### Сброс пароля (провайдеру)

```
Сброс пароля Cita

Ваш новый пароль: {password}
Бизнес: {business.name}

Рекомендуем сменить пароль после входа в систему.
```

## TelegramBotService API

| Метод | Telegram API | Параметры |
|-------|-------------|-----------|
| `send_message(chat_id, text, keyboard?)` | `sendMessage` | chat_id, text, parse_mode=Markdown, reply_markup |
| `edit_message(chat_id, message_id, text, keyboard?)` | `editMessageText` | chat_id, message_id, text, parse_mode, reply_markup |
| `answer_callback_query(callback_id, text?)` | `answerCallbackQuery` | callback_query_id, text |
| `send_photo(chat_id, photo_bytes, caption?)` | `sendPhoto` | chat_id, photo (multipart), caption, parse_mode |

## Ограничения и особенности

| Ограничение | Описание |
|-------------|----------|
| **Rate Limits** | Telegram: 30 msg/sec globally, 1 msg/sec per chat. Не обрабатывается в коде |
| **Markdown** | Используется Markdown v1 (не MarkdownV2). Спецсимволы не экранируются |
| **Нет retry** | Ошибки HTTP логируются, но повторных попыток нет |
| **Нет очереди** | Сообщения отправляются синхронно в рамках request. Нет фоновой очереди |
| **Нет группировки** | Каждое уведомление - отдельное сообщение. Нет batch/digest |
| **Webhook only** | Polling не поддерживается. Webhook URL должен быть настроен вручную |
| **Нет верификации** | Webhook не проверяет X-Telegram-Bot-Api-Secret-Token |
| **Inline keyboards** | Используются для confirm/reject/reschedule. Кнопки обновляются через edit_message |
