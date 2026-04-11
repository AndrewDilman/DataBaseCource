# MongoDB - Операции с данными

## Подключение

```bash
# Через Docker
docker exec -it marketplace-mongodb mongosh -u admin -p 123 --authenticationDatabase admin

#Direct
mongosh "mongodb://admin:123@localhost:27017/marketplace?authSource=admin"
```

## CRUD операции

### Создание (INSERT)

#### Добавить товар

```javascript
db.products.insertOne({
    good_id: 100,
    name: "Новый товар",
    merchant_id: 1,
    category_id: 1,
    merchant_name: "ТехноМир",
    category_name: "Электроника",
    attributes: {},
    tags: [],
    created_at: new Date(),
    updated_at: new Date()
});
```

#### Добавить несколько товаров

```javascript
db.products.insertMany([
    { good_id: 101, name: "Товар 1", merchant_id: 1, category_id: 1 },
    { good_id: 102, name: "Товар 2", merchant_id: 1, category_id: 1 },
    { good_id: 103, name: "Товар 3", merchant_id: 2, category_id: 2 }
]);
```

#### Добавить отзыв

```javascript
db.reviews.insertOne({
    product_id: 1,
    user_id: 6,
    rating: 5,
    comment: "Отличный товар!"
});
```

### Чтение (SELECT)

#### Все товары

```javascript
db.products.find();
```

#### Товары с фильтром

```javascript
// По category_id
db.products.find({ category_id: 1 });

// По merchant_id
db.products.find({ merchant_id: 1 });

// составной фильтр
db.products.find({ category_id: 1, merchant_id: 1 });
```

#### Один товар

```javascript
// По good_id
db.products.findOne({ good_id: 1 });

// По _id
db.products.findOne({ _id: ObjectId("...") });
```

#### Проекция (выбор полей)

```javascript
// Только name и price
db.products.find({}, { name: 1, category_name: 1, _id: 0 });

// Все поля кроме some field
db.products.find({}, { attributes: 0, tags: 0 });
```

#### Сортировка

```javascript
// По имени (A-Z)
db.products.find().sort({ name: 1 });

// По ID (Z-A)
db.products.find().sort({ good_id: -1 });
```

#### Ограничение

```javascript
// Первые 10
db.products.find().limit(10);

// Пропустить первые 5, взять следующие 10
db.products.find().skip(5).limit(10);
```

#### Пагинация

```javascript
const page = 1;
const pageSize = 10;
db.products.find().skip((page - 1) * pageSize).limit(pageSize);
```

### Обновление (UPDATE)

#### Обновить один документ

```javascript
db.products.updateOne(
    { good_id: 1 },
    { $set: { name: "Новое название" } }
);
```

#### Обновить несколько

```javascript
db.products.updateMany(
    { category_id: 1 },
    { $set: { on_sale: true } }
);
```

#### Добавить поле

```javascript
db.products.updateOne(
    { good_id: 1 },
    { $set: { price: 50000 } }
);
```

#### Добавить во вложенный объект

```javascript
db.products.updateOne(
    { good_id: 1 },
    { $set: { "attributes.color": "black" } }
);
```

#### Добавить в массив

```javascript
db.products.updateOne(
    { good_id: 1 },
    { $push: { tags: "new" } }
);
```

#### Удалить поле

```javascript
db.products.updateOne(
    { good_id: 1 },
    { $unset: { old_field: "" } }
);
```

####upsert (создать если нет)

```javascript
db.products.updateOne(
    { good_id: 100 },
    { $set: { name: "Новый товар", merchant_id: 1 } },
    { upsert: true }
);
```

### Удаление (DELETE)

#### Удалить один

```javascript
db.products.deleteOne({ good_id: 1 });
```

#### Удалить несколько

```javascript
db.products.deleteMany({ category_id: 5 });
```

#### Удалить все

```javascript
db.products.deleteMany({});
```

## Агрегации

### pipeline

```javascript
db.products.aggregate([
    { $match: { category_id: 1 } },
    { $group: { _id: "$merchant_id", count: { $sum: 1 } } },
    { $sort: { count: -1 } }
]);
```

### $match - фильтрация

```javascript
db.products.aggregate([
    { $match: { category_id: 1, merchant_id: 1 } }
]);
```

### $group - группировка

```javascript
// Количество товаров по категориям
db.products.aggregate([
    { $group: { 
        _id: "$category_name", 
        count: { $sum: 1 },
        avg_price: { $avg: "$price" }
    } }
]);
```

### $project - проекция

```javascript
db.products.aggregate([
    { $project: { 
        name: 1, 
        category: "$category_name",
        _id: 0 
    } }
]);
```

### $lookup - JOIN

```javascript
db.products.aggregate([
    { $lookup: {
        from: "categories",
        localField: "category_id",
        foreignField: "category_id",
        as: "category_info"
    } }
]);
```

### $unwind - развернуть массив

```javascript
db.products.aggregate([
    { $unwind: "$tags" },
    { $group: { _id: "$tags", count: { $sum: 1 } } }
]);
```

## Полезные запросы

### Топ категорий по количеству товаров

```javascript
db.products.aggregate([
    { $group: { 
        _id: "$category_name", 
        count: { $sum: 1 } 
    } },
    { $sort: { count: -1 } },
    { $limit: 10 }
]);
```

### Товары с атрибутами

```javascript
db.products.find({ 
    attributes: { $exists: true, $ne: {} } 
});
```

### Товары по тегу

```javascript
db.products.find({ 
    tags: "smartphone" 
});
```

### Средний рейтинг товара

```javascript
db.reviews.aggregate([
    { $match: { product_id: 1 } },
    { $group: { 
        _id: "$product_id", 
        avg_rating: { $avg: "$rating" },
        count: { $sum: 1 }
    } }
]);
```

### Отзывы по товарам

```javascript
db.reviews.aggregate([
    { $group: { 
        _id: "$product_id", 
        avg_rating: { $avg: "$rating" },
        count: { $sum: 1 }
    } },
    { $match: { count: { $gte: 3 } } },
    { $sort: { avg_rating: -1 } }
]);
```

## Транзакции

```javascript
session = db.getMongo().startSession();

session.startTransaction();
try {
    db.products.insertOne({ good_id: 200, name: "Т" }, { session });
    db.products.updateOne({ good_id: 200 }, { $set: { price: 100 } }, { session });
    session.commitTransaction();
} catch (e) {
    session.abortTransaction();
} finally {
    session.endSession();
}
```

## Подключение

```bash
docker exec -it marketplace-mongodb mongosh -u admin -p 123 --authenticationDatabase admin
```

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия
- [02_collections.md](02_collections.md) - Коллекции