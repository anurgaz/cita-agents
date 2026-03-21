# cita-agents

4 AI-агента для проекта онлайн-записи [cita.kz](https://cita.kz) (Казахстан, салоны красоты, Telegram Mini App).

## Архитектура

```kroki-plantuml
@startuml
skinparam backgroundColor #1e293b
skinparam shadowing false
skinparam defaultFontName Inter
skinparam defaultFontColor #f8fafc
skinparam ArrowColor #2c7a7b
skinparam RectangleBorderColor #2c7a7b
skinparam NoteBackgroundColor transparent
skinparam NoteBorderColor transparent

package "ДО РАЗРАБОТКИ" {
    rectangle "BA Agent\n(что?)" as BA #B2F5EA
    rectangle "SA Agent\n(как?)" as SA #81E6D9
}

rectangle "Dev Code" as DEV #FED7D7

package "ПОСЛЕ ДЕПЛОЯ" {
    rectangle "TW Agent\n(docs)" as TW #81E6D9
    rectangle "CS Agent\n(support)" as CS #B2F5EA
}

BA -> SA : User Story\nAC (G/W/T)\nБизнес-правила
SA -> DEV : API Spec\nSequence Diag\nTest Cases
DEV -> TW : 
TW -> CS : API Reference\nHow-to Guides\nChangelog\nОтветы\nBug-тикеты\nЭскалации

@enduml
```

**Поток работы:**
1. **BA** — формализует требования в user stories (что нужно сделать?)
2. **SA** — проектирует техническую реализацию (как реализовать?)
3. **Developer** — пишет код по спекам SA
4. **Deploy** в main
5. **TW** — документирует реальное состояние по коду (как работает сейчас?)
6. **CS** — помогает клиентам на основе документации TW (как использовать?)

## Агенты

| Агент | Роль | Артефакты | Зона |
|-------|------|-----------|------|
| **BA** | Business Analyst | User stories, AC, бизнес-сценарии | "Что нужно сделать?" |
| **SA** | System Analyst | API specs, sequence diagrams, test cases | "Как реализовать?" |
| **TW** | Technical Writer | API reference, how-to guides, changelog | "Как работает сейчас?" |
| **CS** | Customer Support | Ответы клиентам, bug-тикеты | "Как использовать?" |

## Быстрый старт

### Требования
- bash 4+
- curl, jq
- `ANTHROPIC_API_KEY` в переменных окружения

### Запуск агента

```bash
# BA: создать user story
./pipeline/run-agent.sh \
  --agent ba \
  --task "Создай user story: клиент хочет отменить запись через Mini App" \
  --context docs/business-rules/booking-rules.md docs/business-rules/cancellation-rules.md

# SA: спроектировать API
./pipeline/run-agent.sh \
  --agent sa \
  --task "API спека для DELETE /api/v1/bookings/{id}" \
  --context docs/data/data-dictionary.md docs/integrations/telegram-bot.md

# TW: написать guide (post-deploy mode)
./pipeline/run-agent.sh \
  --agent tw \
  --task "How-to guide: как подключить Telegram-уведомления" \
  --context docs/integrations/telegram-bot.md \
  --mode post-deploy

# CS: ответить клиенту
./pipeline/run-agent.sh \
  --agent cs \
  --task "Клиент: 'Не могу записаться, нет свободных слотов'" \
  --context docs/business-rules/scheduling-rules.md
```

### Параметры run-agent.sh

| Параметр | Обязательный | Описание |
|----------|:---:|----------|
| `--agent` | да | Тип агента: `ba`, `sa`, `tw`, `cs` |
| `--task` | да | Текст задачи |
| `--context` | нет | Дополнительные .md файлы для контекста |
| `--mode` | нет | Режим работы (для TW: `post-deploy`) |

### Результат
- Артефакт сохраняется в `output/{agent}_{timestamp}.md`
- Автоматическая валидация (4 проверки)
- При провале — retry с feedback (до 3 попыток)

## Валидация

```bash
# Валидировать любой артефакт
./validation/validate.sh path/to/artifact.md

# Валидация + рекомендации для ревью
./pipeline/validate-and-review.sh path/to/artifact.md
```

### 4 проверки

| Проверка | Скрипт | Что делает |
|----------|--------|-----------|
| Constraints | `constraints-check.sh` | Артефакт ссылается на C-NNN, BR-NNN, SR-NNN |
| Completeness | `completeness-check.sh` | Все обязательные поля шаблона заполнены |
| Glossary | `glossary-check.sh` | Термины из glossary.md, нет запрещенных синонимов |
| Consistency | `consistency-check.sh` | Нет конфликтов с business-rules |

## Структура

```
cita-agents/
├── README.md
├── recon-report.md              # Результат разведки кодовой базы
│
├── agents/                       # Профили и промпты агентов
│   ├── ba-agent/
│   │   ├── profile.md
│   │   └── system-prompt.md
│   ├── sa-agent/
│   │   ├── profile.md
│   │   └── system-prompt.md
│   ├── tw-agent/
│   │   ├── profile.md
│   │   └── system-prompt.md
│   └── cs-agent/
│       ├── profile.md
│       └── system-prompt.md
│
├── docs/                         # Контекстная документация
│   ├── context/                  # Общий контекст для всех агентов
│   │   ├── glossary.md           # 26 терминов
│   │   ├── constraints.md        # 11 ограничений (C-001..C-011)
│   │   ├── decision-matrix.md    # Матрица решений 4 агентов
│   │   └── tech-stack.md         # Стек технологий (ADR-light)
│   │
│   ├── business-rules/           # Бизнес-правила (из кода)
│   │   ├── booking-rules.md      # BR-001..BR-012
│   │   ├── scheduling-rules.md   # SR-001..SR-010
│   │   ├── notification-rules.md # NR-001..NR-012
│   │   └── cancellation-rules.md # CR-001..CR-011
│   │
│   ├── integrations/             # Внешние интеграции
│   │   ├── telegram-bot.md       # Bot API: команды, callbacks, webhook
│   │   ├── telegram-miniapp.md   # Mini App: initData, auth, SDK
│   │   └── 2gis.md              # 2GIS Suggest API
│   │
│   ├── data/                     # Модель данных
│   │   └── data-dictionary.md    # 10 сущностей, PII, ER-диаграмма
│   │
│   ├── templates/                # Шаблоны артефактов
│   │   ├── user-story-template.md
│   │   ├── api-spec-template.md
│   │   ├── sequence-diagram-template.md
│   │   ├── test-case-template.md
│   │   ├── how-to-guide-template.md
│   │   ├── api-reference-template.md
│   │   └── bug-report-template.md
│   │
│   └── examples/                 # Эталонные примеры
│       ├── example-user-story.md
│       ├── example-api-spec.md
│       └── example-how-to-guide.md
│
├── validation/                   # Скрипты валидации
│   ├── validate.sh               # Главный runner
│   ├── constraints-check.sh
│   ├── completeness-check.sh
│   ├── glossary-check.sh
│   └── consistency-check.sh
│
├── pipeline/                     # Оркестрация
│   ├── run-agent.sh              # Запуск агента (Claude API + валидация + retry)
│   └── validate-and-review.sh    # Валидация + рекомендации
│
└── output/                       # Результаты работы агентов
    └── (генерируется автоматически)
```

## Контекст проекта

**cita.kz** — сервис онлайн-записи для салонов красоты Казахстана.

- **Backend:** FastAPI, SQLAlchemy 2.0 async, PostgreSQL 16, ClickHouse
- **Frontend:** React 19, Vite, Tailwind, shadcn/ui
- **Mini App:** Next.js 16, Zustand, Telegram WebApp SDK
- **Интеграции:** Telegram Bot API (webhook), 2GIS Suggest API, reCAPTCHA v3
- **Репозиторий:** [github.com/anurgaz/cita](https://github.com/anurgaz/cita)


## C4 Архитектура

```kroki-plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

skinparam backgroundColor #1e293b
skinparam shadowing false
skinparam defaultFontName Inter
skinparam defaultFontColor #f8fafc
skinparam ArrowColor #2c7a7b

Person(client, "Клиент", "Записывается на услуги")
Person(provider, "Провайдер", "Управляет расписанием")

System_Boundary(cita, "Cita.kz") {
    Container(miniapp, "Telegram Mini App", "Next.js, React", "UI для клиентов")
    Container(webview, "Web UI", "React", "Админка и лендинг")
    Container(bot, "Telegram Bot", "Python", "Уведомления и быстрые действия")
    Container(backend, "API Backend", "FastAPI, Python", "Бизнес-логика")
    ContainerDb(db, "Database", "PostgreSQL", "Хранение данных")
}

System_Ext(tg, "Telegram API", "Мессенджер")
System_Ext(gis, "2GIS API", "Геокодинг")

Rel(client, miniapp, "Использует", "HTTPS")
Rel(client, bot, "Получает уведомления", "Telegram")
Rel(provider, webview, "Управляет салоном", "HTTPS")
Rel(provider, bot, "Управляет записями", "Telegram")

Rel(miniapp, backend, "API вызовы", "JSON/HTTPS")
Rel(webview, backend, "API вызовы", "JSON/HTTPS")
Rel(bot, backend, "Webhooks", "JSON/HTTPS")
Rel(backend, db, "Чтение/Запись", "SQL/TCP")

Rel(backend, tg, "Отправка сообщений", "JSON/HTTPS")
Rel(backend, gis, "Поиск адресов", "JSON/HTTPS")
@enduml
```
