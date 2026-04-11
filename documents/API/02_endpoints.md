# API - Эндпоинты

## Продукты

### GET /api/products

Список товаров.

```
GET /api/products
GET /api/products?category_id=1
GET /api/products?limit=10
```

### GET /api/products/:id

Один товар.

```
GET /api/products/1
GET /api/products/abc123 (by _id)
```

### POST /api/products

Создать товар.

```json
{
    "name": "Смартфон",
    "merchant_id": 1,
    "category_id": 1
}
```

### PUT /api/products/:id

Обновить товар.

```json
{
    "name": "Новое название",
    "price": 50000
}
```

## Отчёты

### GET /api/report/top-by-categories

Топ категорий по количеству товаров. Кэшируется в Redis на 5 минут.

```
GET /api/report/top-by-categories
```

Ответ:
```json
{
    "source": "cache",
    "data": [...]
}
```

## Кэш

### DELETE /api/cache/report/top-by-categories

Инвалидировать кэш отчёта.

```
DELETE /api/cache/report/top-by-categories
```

## Health

### GET /health

Проверка здоровья сервиса.

```
GET /health
```

## Примеры

### curl

```bash
# Список товаров
curl http://localhost:4000/api/products

# Товары категории
curl http://localhost:4000/api/products?category_id=1

# Создать товар
curl -X POST http://localhost:4000/api/products \
    -H "Content-Type: application/json" \
    -d '{"name":"Test","merchant_id":1,"category_id":1}'

# Топ категорий
curl http://localhost:4000/api/report/top-by-categories
```

## Смотрите также

- [01_overview.md](01_overview.md) - Обзор API