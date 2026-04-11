# MongoDB - Коллекции в проекте

## Обзор

В проекте используются 4 основные коллекции:
- **products** - каталог товаров
- **reviews** - отзывы
- **categories** - категории
- **events** - временные события (TTL)

## Инициализация

Инициализация выполняется через mongodb-init.js при первом запуске:

```javascript
db = db.getSiblingDB('marketplace');

db.createUser({
  user: 'app_user',
  pwd: 'app_password',
  roles: [{ role: 'readWrite', db: 'marketplace' }]
});

db.createCollection('products');
db.createCollection('reviews');
db.createCollection('categories');
db.createCollection('events');
```

## Коллекция products

Основная коллекция товаров с гибкой схемой.

### Структура документа

```javascript
{
    "_id": ObjectId("..."),
    "good_id": 1,
    "name": "Смартфон Samsung Galaxy",
    "merchant_id": 1,
    "category_id": 1,
    "merchant_name": "ТехноМир",
    "category_name": "Электроника",
    "attributes": {
        "color": "black",
        "warranty": "1 year"
    },
    "tags": ["smartphone", "5g"],
    "created_at": ISODate("2024-01-01T00:00:00Z"),
    "updated_at": ISODate("2024-01-01T00:00:00Z")
}
```

### Поля

| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| _id | ObjectId | Да | Уникальный ID MongoDB |
| good_id | Integer | Да | ID товара из PostgreSQL |
| name | String | Да | Название товара |
| merchant_id | Integer | Да | ID продавца |
| category_id | Integer | Да | ID категории |
| merchant_name | String | Нет | Имя продавца |
| category_name | String | Нет | Имя категории |
| attributes | Object | Нет | Дополнительные атрибуты |
| tags | Array | Нет | Теги |
| created_at | Date | Нет | Дата создания |
| updated_at | Date | Нет | Дата обновления |

### Примеры документов

```javascript
// Минимальный документ
{
    "good_id": 1,
    "name": "Смартфон",
    "merchant_id": 1,
    "category_id": 1
}

// Полный документ
{
    "good_id": 2,
    "name": "Ноутбук ASUS VivoBook",
    "merchant_id": 1,
    "category_id": 1,
    "merchant_name": "ТехноМир",
    "category_name": "Электроника",
    "attributes": {
        "ram": "16GB",
        "ssd": "512GB",
        "processor": "Intel i7",
        "weight": "1.5kg"
    },
    "tags": ["laptop", "asus", "windows"],
    "created_at": ISODate("2024-01-15T10:30:00Z"),
    "updated_at": ISODate("2024-01-15T10:30:00Z")
}
```

## Коллекция reviews

Отзывы о товарах.

### Структура документа

```javascript
{
    "_id": ObjectId("..."),
    "product_id": 1,
    "user_id": 6,
    "rating": 5,
    "comment": "Отличный товар! Рекомендую."
}
```

### Поля

| Поле | Ти�� | Обязательное | Описание |
|------|-----|--------------|----------|
| _id | ObjectId | Да | Уникальный ID |
| product_id | Integer | Да | ID товара (good_id) |
| user_id | Integer | Да | ID пользователя |
| rating | Integer | Да | Рейтинг (1-5) |
| comment | String | Нет | Текст отзыва |

### Ограничения

- UNIQUE на (product_id, user_id) - один отзыв от пользователя на товар
- rating: 1-5

## Коллекция categories

Вспомогательная коллекция категорий.

### Структура документа

```javascript
{
    "_id": ObjectId("..."),
    "category_id": 1,
    "name": "Электроника"
}
```

### Поля

| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| _id | ObjectId | Да | Уникальный ID |
| category_id | Integer | Да | ID категории |
| name | String | Да | Название |

### Ограничения

- UNIQUE на category_id

## Коллекция events

Временная коллекция для событий с TTL.

### Структура документа

```javascript
{
    "_id": ObjectId("..."),
    "event_type": "user_login",
    "user_id": 1,
    "data": { "ip": "192.168.1.1" },
    "created_at": ISODate("2024-01-01T12:00:00Z")
}
```

### Особенности

-TTL индекс на поле created_at с expireAfterSeconds = 86400 (24 часа)
- Документы автоматически удаляются через 24 часа

## Миграция данных

Данные мигрируют из PostgreSQL через mongoimport:

```bash
# Экспорт из PostgreSQL
psql -h postgres -U admin -d marketplace -t -A -c "
    SELECT json_build_object(
        'good_id', g.good_id,
        'name', g.name,
        'merchant_id', g.merch_id
    )...
" -o /tmp/products.json

# Импорт в MongoDB
mongoimport --db marketplace --collection products --file /tmp/products.json --jsonArray
```

## Подключение

```bash
#mongosh
docker exec -it marketplace-mongodb mongosh -u admin -p 123 --authenticationDatabase admin

# Использовать БД
use marketplace

# Показать коллекции
show collections
```

## Количество документов

```javascript
db.products.countDocuments()
db.reviews.countDocuments()
db.categories.countDocuments()
db.events.countDocuments()
```

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия
- [03_operations.md](03_operations.md) - Операции
- [04_indexes.md](04_indexes.md) - Индексы
- [05_schema_validation.md](05_schema_validation.md) - Валидация