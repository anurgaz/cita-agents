# 2GIS Suggest API Integration

> Источник: `backend/app/api/v1/endpoints/location.py`

## Общие сведения

| Параметр | Значение |
|----------|----------|
| API | 2GIS Suggest API v3.0 |
| Base URL | `https://catalog.api.2gis.com/3.0/suggests` |
| Метод | Server-side proxy (Backend -> 2GIS -> Frontend) |
| API Key | `settings.TWOGIS_API_KEY` (env) |
| HTTP Client | `httpx.AsyncClient` |
| Регион | Казахстан (`country_id=4`) |

## Endpoints

### GET /api/v1/location/cities

Автокомплит городов Казахстана.

**Параметры:**

| Параметр | Тип | Описание |
|----------|-----|----------|
| `q` | string | Поисковый запрос (название города) |

**Запрос к 2GIS:**

```
GET https://catalog.api.2gis.com/3.0/suggests
?key={API_KEY}
&q={q}
&type=adm_div.city
&fields=items.point
&locale=ru_KZ
&country_id=4
```

**Фильтрация:** `type=adm_div.city` - только города (не районы, не улицы).

**Ответ (mapped):**

```json
[
  {
    "name": "Алматы",
    "full_name": "Алматы, Казахстан",
    "point": { "lat": 43.238, "lon": 76.945 }
  }
]
```

### GET /api/v1/location/addresses

Автокомплит адресов с привязкой к точке (городу).

**Параметры:**

| Параметр | Тип | Описание |
|----------|-----|----------|
| `q` | string | Поисковый запрос (адрес) |
| `lat` | float | Широта точки привязки |
| `lon` | float | Долгота точки привязки |

**Запрос к 2GIS:**

```
GET https://catalog.api.2gis.com/3.0/suggests
?key={API_KEY}
&q={q}
&type=street,branch,building,adm_div,crossroad
&fields=items.point
&locale=ru_KZ
&country_id=4
&sort_point={lon},{lat}
```

**Особенности:**
- `sort_point` - сортировка по близости к выбранному городу
- Формат: `{lon},{lat}` (долгота первая!)
- Типы: street, branch, building, adm_div, crossroad

## Архитектура

```kroki-plantuml
@startuml
skinparam backgroundColor #1e293b
skinparam shadowing false
skinparam defaultFontName Inter
skinparam defaultFontColor #f8fafc
skinparam ArrowColor #2c7a7b
skinparam RectangleBorderColor #2c7a7b

participant "Frontend\n(React)" as fe
participant "Backend\n(FastAPI proxy)" as be
participant "2GIS API\n(Suggest API)" as gis

fe -> be : GET /api/v1/location/cities?q=...\nGET /api/v1/location/addresses?q=...
activate be

be -> gis : GET https://catalog.api.2gis.com/3.0/suggests?key=...
activate gis
gis --> be : 200 OK (2gis response)
deactivate gis

be -> be : map to [{name, full_name, point}]
be --> fe : 200 OK (mapped array)
deactivate be
@enduml
```

## Использование в UI

1. Пользователь выбирает **город** (автокомплит cities)
2. Координаты города сохраняются
3. Пользователь вводит **адрес** (автокомплит addresses с привязкой к городу)
4. Выбранный адрес сохраняется в `Business.address`

## Ограничения

| Ограничение | Описание |
|-------------|----------|
| **Только Казахстан** | `country_id=4` жестко задан |
| **Нет кэширования** | Каждый запрос идет напрямую к 2GIS |
| **Нет debounce на бэке** | Debounce должен быть на фронте |
| **API Key на бэкенде** | Ключ не передается на фронт (безопасно) |
| **Нет fallback** | При недоступности 2GIS - ошибка 502 |
| **Rate limits** | 2GIS: ~100 req/sec на ключ. Не мониторится |
| **Нет геокодинга** | Только suggest. Обратный геокодинг не используется |
| **Координаты не сохраняются** | В Business хранится только строка address, не lat/lon |
