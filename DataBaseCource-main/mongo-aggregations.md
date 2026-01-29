# Aggregation pipelines (маркетплейс / магазин)

Примеры для выполнения в `mongosh` в БД `marketplace`.

---

## 1. Топ категорий по количеству товаров ($match, $group, $project, $sort, $limit)

```javascript
db.products.aggregate([
  { $match: {} },
  { $group: { _id: "$category_name", count: { $sum: 1 } } },
  { $project: { category: "$_id", count: 1, _id: 0 } },
  { $sort: { count: -1 } },
  { $limit: 10 }
]);
```

---

## 2. Средний рейтинг по товарам ($match, $group, $project, $sort)

```javascript
db.reviews.aggregate([
  { $match: {} },
  { $group: { _id: "$product_id", avgRating: { $avg: "$rating" }, count: { $sum: 1 } } },
  { $project: { product_id: "$_id", avgRating: { $round: ["$avgRating", 2] }, count: 1, _id: 0 } },
  { $sort: { avgRating: -1 } },
  { $limit: 20 }
]);
```

---

## 3. Топ продавцов по числу товаров ($match, $group, $project, $sort, $limit)

```javascript
db.products.aggregate([
  { $match: {} },
  { $group: { _id: "$merchant_id", merchant_name: { $first: "$merchant_name" }, count: { $sum: 1 } } },
  { $project: { merchant_id: "$_id", merchant_name: 1, count: 1, _id: 0 } },
  { $sort: { count: -1 } },
  { $limit: 10 }
]);
```

---

## 4. $unwind: распределение рейтигов по категориям (через $lookup 1:N)

Сначала присоединяем продукт к отзыву (1 продукт : N отзывов), затем разворачиваем теги/массивы при необходимости.

```javascript
db.reviews.aggregate([
  { $match: {} },
  { $lookup: { from: "products", localField: "product_id", foreignField: "good_id", as: "product" } },
  { $unwind: { path: "$product", preserveNullAndEmptyArrays: true } },
  { $group: {
    _id: { category: "$product.category_name", rating: "$rating" },
    count: { $sum: 1 }
  } },
  { $project: { category: "$_id.category", rating: "$_id.rating", count: 1, _id: 0 } },
  { $sort: { category: 1, rating: 1 } },
  { $limit: 50 }
]);
```

---

## 5. $lookup N:N (товары + отзывы): товары с их отзывами и средним рейтингом

```javascript
db.products.aggregate([
  { $match: {} },
  { $lookup: { from: "reviews", localField: "good_id", foreignField: "product_id", as: "reviews" } },
  { $project: {
    good_id: 1,
    name: 1,
    category_name: 1,
    reviewCount: { $size: "$reviews" },
    avgRating: { $cond: [
      { $gt: [{ $size: "$reviews" }, 0] },
      { $round: [{ $avg: "$reviews.rating" }, 2] },
      null
    ]}
  } },
  { $sort: { avgRating: -1, reviewCount: -1 } },
  { $limit: 20 }
]);
```

---

## explain("executionStats") до/после индексов

Выполнить до создания индексов и после:

```javascript
db.products.aggregate(
  [
    { $match: { category_id: 1 } },
    { $group: { _id: "$merchant_id", count: { $sum: 1 } } },
    { $sort: { count: -1 } },
    { $limit: 5 }
  ],
  { explain: true }
);
// или
db.products.explain("executionStats").aggregate([ ... ]);
```

Индекс для этого запроса: `{ category_id: 1, merchant_id: 1 }` (уже есть в mongodb-init.js).
