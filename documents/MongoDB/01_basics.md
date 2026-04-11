# MongoDB - Базовые понятия

## Введение

MongoDB - это документоориентированная система управления базами данных (NoSQL). Данные хранятся в виде JSON-подобных документов BSON, что обеспечивает гибкость схемы и масштабируемость.

## Основные понятия

### Документ (Document)

Документ - это основная единица данных в MongoDB. Это JSON-подобный объект, хранящийся в BSON формате.

```javascript
{
    "_id": ObjectId("..."),
    "name": "Смартфон Samsung",
    "price": 50000,
    "in_stock": true,
    "tags": ["electronics", "samsung"],
    "specs": {
        "ram": "8GB",
        "storage": "256GB"
    }
}
```

### Коллекция (Collection)

Коллекция - это группа документов. Аналог таблицы в реляционных БД, но без фиксированной схемы.

```javascript
db.products // коллекция товаров
```

### База данных (Database)

База данных содержит коллекции. Одна БД mongo может содержать несколько коллекций.

```javascript
use marketplace // переключиться на БД
db // показать текущую БД
```

## BSON типы данных

MongoDB использует BSON (Binary JSON):

| BSON тип | Пример | Описание |
|----------|--------|----------|
| Double | 3.14 | Число с плавающей точкой |
| String | "text" | Текст |
| Object | {...} | Вложенный документ |
| Array | [...] | Массив |
| ObjectId | ObjectId("...") | Уникальный ID |
| Boolean | true/false | Логический |
| Date | ISODate("...") | Дата |
| Null | null | Null |
| NumberLong | NumberLong(123) | 64-битное целое |
| NumberInt | NumberInt(123) | 32-битное целое |

## ObjectId

Уникальный идентификатор документа:

```javascript
{
    "_id": ObjectId("507f1f77bcf86cd799439011")
}
```

Структура ObjectId:
- 4 байта - timestamp
- 3 байта - machine ID
- 2 байта - process ID
- 3 байта - counter

## Запросы к MongoDB

### Подключение

```bash
# Через mongosh
mongosh "mongodb://admin:123@localhost:27017/marketplace?authSource=admin"

# Через Docker
docker exec -it marketplace-mongodb mongosh -u admin -p 123 --authenticationDatabase admin
```

### Создание документов

```javascript
// Один документ
db.products.insertOne({
    name: "Смартфон Samsung",
    price: 50000,
    category_id: 1
});

// Несколько документов
db.products.insertMany([
    { name: "Ноутбук", price: 80000 },
    { name: "Планшет", price: 40000 }
]);
```

### Чтение документов

```javascript
// Все документы
db.products.find()

// С фильтром
db.products.find({ category_id: 1 })

// Первый документ
db.products.findOne({ name: "Смартфон" })

// Проекция (только нужные поля)
db.products.find({}, { name: 1, price: 1, _id: 0 })
```

### Обновление документов

```javascript
// Обновить один документ
db.products.updateOne(
    { name: "Смартфон" },
    { $set: { price: 55000 } }
)

// Обновить несколько
db.products.updateMany(
    { category_id: 1 },
    { $set: { on_sale: true } }
)

// Заменить документ
db.products.replaceOne(
    { _id: ObjectId("...") },
    { name: "Новый товар", price: 10000 }
)
```

### Удаление документов

```javascript
// Удалить один
db.products.deleteOne({ name: "Товар" })

// Удалить несколько
db.products.deleteMany({ category_id: 5 })
```

## Индексы

Индексы ускоряют поиск:

```javascript
// Простой индекс
db.products.createIndex({ name: 1 })

// Составной индекс
db.products.createIndex({ category_id: 1, price: 1 })

// Уникальный индекс
db.products.createIndex({ good_id: 1 }, { unique: true })

// TTL индекс (удаление по времени)
db.events.createIndex({ created_at: 1 }, { expireAfterSeconds: 3600 })
```

## Агрегации

Агрегации - мощный инструмент для трансформации данных:

```javascript
db.products.aggregate([
    { $match: { category_id: 1 } },
    { $group: { _id: "$merchant_id", count: { $sum: 1 } } },
    { $sort: { count: -1 } }
])
```

### Стадии агрегации

| Стадия | Описание |
|--------|----------|
| $match | Фильтрация |
| $project | Проекция |
| $group | Группировка |
| $sort | Сортировка |
| $limit | Ограничение |
| $skip | Пропуск |
| $unwind | Развернуть массив |
| $lookup | JOIN с другой коллекцией |

## Гибкая схема

В отличие от реляционных БД, коллекции MongoDB не требуют фиксированной схемы:

```javascript
// Документ 1
{ name: "Товар 1", price: 100 }

// Документ 2
{ name: "Товар 2", price: 200, description: "Описание" }

// Документ 3
{ name: "Товар 3", tags: ["new", "sale"] }
```

Но можно добавить валидацию схемы (JSON Schema).

## Транзакции

MongoDB поддерживает multi-document ACID транзакции:

```javascript
session = db.getMongo().startSession();

session.startTransaction();
try {
    db.orders.insertOne({ ... }, { session });
    db.products.updateOne({ ... }, { $inc: { stock: -1 } }, { session });
    session.commitTransaction();
} catch (e) {
    session.abortTransaction();
} finally {
    session.endSession();
}
```

## Подключение к БД

### mongosh

```bash
# Локальное подключение
mongosh

# С аутентификацией
mongosh "mongodb://admin:123@localhost:27017/marketplace?authSource=admin"
```

### Параметры подключения

| Параметр | Описание | По умолчанию |
|---------|----------|--------------|
| host | Хост | localhost |
| port | Порт | 27017 |
| db | База данных | test |
| u | Пользователь | - |
| p | Пароль | - |
| authenticationDatabase | БД аутентификации | admin |

## Основные команды mongosh

```javascript
// Показать БД
show dbs

// Переключить БД
use marketplace

// Показать коллекции
show collections

// Показать 帮助
help

// Выйти
exit
```

## Смотрите также

- [02_collections.md](02_collections.md) - Коллекции в про��кте
- [03_operations.md](03_operations.md) - Операции с данными
- [04_indexes.md](04_indexes.md) - Индексы
- [05_schema_validation.md](05_schema_validation.md) - Валидация схемы