# MongoDB - Индексы

## Введение

Индексы в MongoDB ускоряют запросы. Без индексовMongoDB выполняет полное сканирование коллекции.

## Создание индексов

### Простой индекс

```javascript
db.products.createIndex({ name: 1 });  // по возрастанию
db.products.createIndex({ name: -1 }); // по убыванию
```

### Уникальный индекс

```javascript
db.products.createIndex({ good_id: 1 }, { unique: true });
```

### Составной индекс

```javascript
// Индекс по category_id и merchant_id
db.products.createIndex({ category_id: 1, merchant_id: 1 });
```

## Индексы в проекте

### Коллекция products

```javascript
// Уникальный по good_id (ID товара из PostgreSQL)
db.products.createIndex({ good_id: 1 }, { unique: true });

// Индекс для поиска по продавцу
db.products.createIndex({ merchant_id: 1 });

// Индекс для поиска по категории
db.products.createIndex({ category_id: 1 });

// Составной для фасетного поиска
db.products.createIndex({ category_id: 1, merchant_id: 1 });

// Partial для поиска по каталогу
db.products.createIndex(
    { category_id: 1, name: 1 },
    { 
        name: 'idx_category_name',
        partialFilterExpression: { category_id: { $gt: 0 } }
    }
);
```

### Коллекция reviews

```javascript
// Индекс для отзывов товара
db.reviews.createIndex({ product_id: 1 });

// Уникальный - один отзыв от пользователя
db.reviews.createIndex({ user_id: 1, product_id: 1 }, { unique: true });

// Для расчёта среднего рейтинга
db.reviews.createIndex({ product_id: 1, rating: 1 });
```

### Коллекция categories

```javascript
// Уникальный category_id
db.categories.createIndex({ category_id: 1 }, { unique: true });

// Поиск по имени
db.categories.createIndex({ name: 1 });
```

### Коллекция events (TTL)

```javascript
// TTL индекс - удаление через 24 часа
db.events.createIndex({ created_at: 1 }, { expireAfterSeconds: 86400 });
```

## Типы индексов

### B-tree индекс (по умолчанию)

```javascript
db.products.createIndex({ name: 1 });
```

### Hash индекс

```javascript
db.products.createIndex({ _id: "hashed" });
```

### Text индекс

```javascript
db.products.createIndex({ name: "text", description: "text" });

// Поиск по тексту
db.products.find({ $text: { $search: "smartphone" } });
```

### 2dsphere индекс (геоданные)

```javascript
db.places.createIndex({ location: "2dsphere" });
```

### 2d индекс (геоточки)

```javascript
db.places.createIndex({ location: "2d" });
```

## Опции индексов

### unique - уникальность

```javascript
db.products.createIndex({ good_id: 1 }, { unique: true });
```

### sparse - пропуск null

```javascript
db.products.createIndex({ price: 1 }, { sparse: true });
```

### expireAfter - TTL

```javascript
db.events.createIndex({ created_at: 1 }, { expireAfterSeconds: 3600 });
```

### partialFilterExpression - частичный индекс

```javascript
// Индекс только для товаров с ценой
db.products.createIndex(
    { price: 1 },
    { partialFilterExpression: { price: { $exists: true } } }
);
```

### name - имя индекса

```javascript
db.products.createIndex(
    { name: 1 },
    { name: "idx_name" }
);
```

### background - фоновое создание

```javascript
db.products.createIndex({ name: 1 }, { background: true });
```

## Управление индексами

### Просмотреть индексы коллекции

```javascript
db.products.getIndexes();
```

### Удалить индекс

```javascript
// По имени
db.products.dropIndex("idx_name");

// По спецификации
db.products.dropIndex({ name: 1 });
```

### Удалить все пользовательские индексы

```javascript
db.products.dropIndexes();
```

### Информация об индексе

```javascript
db.products.indexInfo();
```

## Использование explain

```javascript
// Посмотреть, какой индекс используется
db.products.find({ category_id: 1 }).explain();

// Детали
db.products.find({ category_id: 1 }).explain("executionStats");
```

## Оптимизация запросов

###covering index

```javascript
// Индекс покрывает запрос
db.products.createIndex({ category_id: 1, name: 1, merchant_id: 1 });

// Запрос
db.products.find(
    { category_id: 1 },
    { name: 1, merchant_id: 1, _id: 0 }
);
```

### Составные индексы

Порядок полей важен:

```javascript
// category_id first, then merchant_id
db.products.createIndex({ category_id: 1, merchant_id: 1 });

// Запрос по category_id
db.products.find({ category_id: 1 });

// Запрос по обоим полям
db.products.find({ category_id: 1, merchant_id: 1 });

// НЕ работает: запрос только по merchant_id
db.products.find({ merchant_id: 1 });
```

## Производительность

### Создание индекса

```javascript
// Foreground (быстрее, блокирует запись)
db.products.createIndex({ name: 1 });

// Background (медленнее, не блокирует)
db.products.createIndex({ name: 1 }, { background: true });
```

### Размер индексов

```javascript
db.products.stats();
```

## Подключение

```bash
docker exec -it marketplace-mongodb mongosh -u admin -p 123 --authenticationDatabase admin
```

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия
- [02_collections.md](02_collections.md) - Коллекции
- [03_operations.md](03_operations.md) - Операции