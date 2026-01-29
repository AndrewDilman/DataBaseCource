# API маркетплейса (MongoDB + Redis)

REST-слой для демонстрации работы с MongoDB и кэшированием в Redis.

## Запуск

Из корня проекта:

```bash
docker compose up -d mongodb redis api
```

API слушает порт **4000**.

Локально (при уже запущенных MongoDB и Redis):

```bash
cd api
npm install
npm start
```

Переменные окружения: `MONGODB_URI`, `REDIS_URL`, `PORT` (по умолчанию 4000).

## Endpoints

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/api/products` | Список товаров (опционально `?category_id=`, `?limit=`) |
| GET | `/api/products/:id` | Один товар по `good_id` или `_id` |
| POST | `/api/products` | Создать товар (инвалидирует кэш отчёта в Redis) |
| PUT | `/api/products/:id` | Обновить товар по `good_id` (инвалидирует кэш) |
| GET | `/api/report/top-by-categories` | Отчёт «топ по категориям» — **кэш в Redis**; при первом запросе считается из MongoDB и сохраняется в Redis |
| DELETE | `/api/cache/report/top-by-categories` | Сброс кэша отчёта (для отладки) |
| GET | `/health` | Проверка работы API, MongoDB и Redis |

## Redis

- **Ключ кэша:** `report:top_by_categories`
- **TTL:** 300 сек (5 мин). При каждом **POST /api/products** и **PUT /api/products/:id** ключ принудительно удаляется (`DEL`), чтобы при следующем запросе к `/api/report/top-by-categories` отчёт пересчитался из MongoDB и снова попал в кэш.
- В ответе отчёта поле `source: "cache"` или `source: "db"` показывает, отдан ответ из Redis или из БД.

## Примеры

```bash
# Список товаров
curl http://localhost:4000/api/products

# Товары одной категории
curl "http://localhost:4000/api/products?category_id=1&limit=5"

# Отчёт (первый вызов — из БД, повторный — из кэша)
curl http://localhost:4000/api/report/top-by-categories

# Создать товар (кэш отчёта сбрасывается)
curl -X POST http://localhost:4000/api/products -H "Content-Type: application/json" -d "{\"good_id\":9999,\"name\":\"Test\",\"merchant_id\":1,\"category_id\":1,\"merchant_name\":\"M\",\"category_name\":\"Cat\"}"
```
