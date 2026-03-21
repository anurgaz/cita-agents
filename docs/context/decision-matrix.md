# Decision Matrix

> Кто что делает. Определяет зоны ответственности четырёх агентов.
> При конфликте — эскалация на человека (PO или Tech Lead).

## Ключевой принцип

| Фаза | Вопрос | Агент |
|---|---|---|
| Планирование (до разработки) | «Что нужно сделать?» | BA, SA |
| Документирование (после деплоя) | «Как это работает сейчас?» | TW |
| Эксплуатация (runtime) | «Как мне это использовать?» / «У меня не работает» | CS |

---

## Уровни полномочий

| Уровень | Описание |
|---|---|
| **auto** | Агент выполняет самостоятельно, без согласования |
| **suggest+approve** | Агент генерирует артефакт, человек утверждает |
| **manual only** | Только человек, агент не участвует |

---

## Матрица действий

### BA Agent (Business Analyst)

| Действие | Уровень | Кто апрувит | Примечание |
|---|---|---|---|
| Генерация user story | suggest+approve | PO | Формат: docs/templates/user-story-template.md |
| Генерация acceptance criteria | suggest+approve | PO | Часть user story |
| Описание бизнес-сценария | suggest+approve | PO | Happy path + edge cases |
| Предложение бизнес-правила | suggest+approve | PO | BA только предлагает, решение за PO |
| Описание интеграционного сценария (бизнес-уровень) | suggest+approve | PO | Telegram, 2GIS — что происходит, не как |
| Приоритизация бэклога | manual only | PO | BA может предложить, но не решает |

### SA Agent (System Analyst)

| Действие | Уровень | Кто апрувит | Примечание |
|---|---|---|---|
| Генерация API спеки (новый эндпоинт) | suggest+approve | Tech Lead | OpenAPI 3.1, формат: docs/templates/api-spec-template.md |
| Генерация sequence diagram | suggest+approve | Tech Lead | PlantUML, happy path + min 2 error paths |
| Генерация тест-кейсов | auto | — | По user story или API спеке |
| Обновление data dictionary | suggest+approve | Tech Lead | При изменении схемы данных |
| Анализ влияния (impact analysis) | suggest+approve | Tech Lead | При изменении существующего API |
| Проектирование error codes | suggest+approve | Tech Lead | HTTP status + application-level codes |

### TW Agent (Technical Writer)

| Действие | Уровень | Кто апрувит | Примечание |
|---|---|---|---|
| Обновление API reference после деплоя | auto | — | По коду и OpenAPI schema |
| Генерация how-to guide для клиентов | suggest+approve | PO | Формат: docs/templates/how-to-guide-template.md |
| Генерация how-to guide для провайдеров | suggest+approve | PO | Настройка бизнеса, расписания, Telegram |
| Обновление changelog | auto | — | По git diff / release notes |
| Reverse engineering: доку по коду | suggest+approve | Tech Lead | Когда документации нет, но код есть |
| Обновление glossary.md | suggest+approve | PO | При появлении новых терминов |

### CS Agent (Customer Support)

| Действие | Уровень | Кто апрувит | Примечание |
|---|---|---|---|
| Ответ на вопрос клиента | auto | — | На основе how-to guides и FAQ |
| Ответ на вопрос провайдера | auto | — | На основе admin docs и FAQ |
| Создание bug-тикета | suggest+approve | Tech Lead | Формат: docs/templates/bug-report-template.md |
| Эскалация жалобы | manual only | PO | CS только формирует, не решает |
| Диагностика проблемы | auto | — | Checklist: статус, логи, браузер, версия |
| Предложение workaround | auto | — | Временное решение до fix |

### Действия без агента

| Действие | Уровень | Кто решает | Примечание |
|---|---|---|---|
| Изменение бизнес-правила | manual only | PO | Агенты обновляют доки после решения |
| Изменение архитектуры | manual only | Tech Lead | SA может предложить анализ влияния |
| Деплой в production | manual only | DevOps / Tech Lead | Агенты не имеют доступа к prod |
| Удаление данных клиента | manual only | PO + DPO | GDPR/compliance |
| Изменение тарифов/цен | manual only | PO | BA может описать impact |

---

## Взаимодействие между агентами

```kroki-plantuml
@startuml
skinparam backgroundColor #1e293b
skinparam shadowing false
skinparam defaultFontName Inter
skinparam defaultFontColor #f8fafc
skinparam ArrowColor #2c7a7b
skinparam RectangleBorderColor #2c7a7b

rectangle "PO / Stakeholder" as PO #234E52
rectangle "BA Agent" as BA #2C7A7B
rectangle "SA Agent" as SA #319795
rectangle "Разработка + Деплой\n(человек)" as DEV #9B2C2C
rectangle "TW Agent" as TW #319795
rectangle "CS Agent" as CS #2C7A7B
rectangle "Tech Lead" as TL #9B2C2C

PO -down-> BA : задача
BA -down-> SA : user story +\nacceptance criteria
SA -down-> DEV : API spec + sequence\ndiagram + test cases
DEV -down-> TW : деплой выполнен
TW -down-> CS : API reference +\nhow-to guides + changelog

CS -right-> TL : bug report
TL -up-> BA : новая фича / фикс
TL -up-> SA : новая фича / фикс
@enduml
```

## Правила эскалации

1. **CS → Tech Lead:** если проблема требует изменения кода (bug)
2. **CS → PO:** если жалоба или запрос на фичу от клиента
3. **BA → PO:** любое изменение бизнес-правил
4. **SA → Tech Lead:** изменение API контракта, схемы данных
5. **TW → PO:** если документация противоречит текущему поведению системы
