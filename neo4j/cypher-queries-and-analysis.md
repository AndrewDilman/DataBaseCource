# Задания 6–8: Cypher (Neo4j), сравнение с Postgres/Mongo, анализ

Модель графа в проекте: узлы `User` (customer/merchant), `Product`, `Category`; связи `SOLD_BY` (Product→User), `IN_CATEGORY` (Product→Category). В расширенной модели могут быть заказы и отзывы (ниже приведены варианты запросов с `ORDERED`/`REVIEWED` там, где нужно).

---

## 6. Сценарии Postgres/Mongo с JOIN/$lookup и их аналоги в Cypher (MATCH)

### 6.1 Postgres: товары с продавцом и категорией (3 таблицы)

**PostgreSQL:**
```sql
SELECT g.good_id, g.name AS product_name, u.name AS merchant_name, c.name AS category_name
FROM goods g
JOIN users u ON g.merch_id = u.user_id
JOIN categories c ON g.caty_id = c.caty_id
ORDER BY category_name, product_name
LIMIT 10;
```

**Cypher (Neo4j):**
```cypher
MATCH (g:Product)-[:SOLD_BY]->(u:User)
MATCH (g)-[:IN_CATEGORY]->(c:Category)
RETURN g.productId AS good_id, g.name AS product_name, u.name AS merchant_name, c.name AS category_name
ORDER BY category_name, product_name
LIMIT 10;
```

### 6.2 Mongo: отзывы с продуктом ($lookup 1:N), затем группировка по категории и рейтингу

**MongoDB ($lookup + $unwind):**
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

**Cypher (если в графе есть связь REVIEWED с рейтингом):**
```cypher
MATCH (u:User)-[r:REVIEWED]->(p:Product)-[:IN_CATEGORY]->(c:Category)
WITH c.name AS category, r.rating AS rating, count(*) AS cnt
RETURN category, rating, cnt
ORDER BY category, rating
LIMIT 50;
```

### 6.3 Mongo: товары с отзывами и средним рейтингом ($lookup N:N)

**MongoDB:**
```javascript
db.products.aggregate([
  { $match: {} },
  { $lookup: { from: "reviews", localField: "good_id", foreignField: "product_id", as: "reviews" } },
  { $project: {
    good_id: 1, name: 1, category_name: 1,
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

**Cypher (при наличии связи REVIEWED с свойством rating):**
```cypher
MATCH (p:Product)
OPTIONAL MATCH (u:User)-[rev:REVIEWED]->(p)
WITH p, count(rev) AS reviewCount, avg(rev.rating) AS avgRating
RETURN p.productId AS good_id, p.name, p.categoryId AS category_id,
       reviewCount,
       round(avgRating * 100) / 100 AS avgRating
ORDER BY avgRating DESC, reviewCount DESC
LIMIT 20;
```

### 6.4 Postgres: заказы с покупателем, товаром и продавцом (4 таблицы)

**PostgreSQL:**
```sql
SELECT o.id AS order_id, u_c.name AS customer_name, g.name AS product_name, u_m.name AS merchant_name
FROM orders o
JOIN users u_c ON o.user_id = u_c.user_id
JOIN goods g ON o.good_id = g.good_id
JOIN users u_m ON g.merch_id = u_m.user_id
ORDER BY o.id LIMIT 10;
```

**Cypher (при наличии узлов заказов или связи ORDERED):**
```cypher
// Вариант: заказ как связь (Customer)-[:ORDERED]->(Product), продавец через SOLD_BY
MATCH (u_c:User {type: 'customer'})-[:ORDERED]->(g:Product)-[:SOLD_BY]->(u_m:User)
RETURN u_c.name AS customer_name, g.name AS product_name, u_m.name AS merchant_name
ORDER BY customer_name
LIMIT 10;
```

---

### Сравнение: какой запрос проще и нагляднее

| Критерий | Postgres/Mongo | Cypher (Neo4j) |
|----------|----------------|----------------|
| **Читаемость** | JOIN перечисляют таблицы и ключи; $lookup требует указания коллекций и полей. Цепочка связей неочевидна. | **MATCH** явно задаёт цепочку узлов и рёбер: (Товар)-[:SOLD_BY]->(Продавец). Смысл запроса совпадает с формулировкой на естественном языке. |
| **Многотабличные цепочки** | 4–5 JOIN с разными алиасами (u_c, u_m, g, c) — легко ошибиться в условиях. | Один MATCH-паттерн: (customer)-[:ORDERED]->(product)-[:SOLD_BY]->(merchant). Структура графа видна в запросе. |
| **Производительность** | Зависит от индексов по FK; планировщик строит дерево JOIN. | Обход по связям — родная операция графовой СУБД; не нужны промежуточные джойны по ключам. |
| **Гибкость** | Добавление новой таблицы в цепочку = новый JOIN/$lookup. | Добавление шага = новый отрезок в паттерне (например, -[:IN_CATEGORY]->(c)). |

**Вывод:** для запросов, которые по смыслу являются «обходом связей» (товар → продавец, товар → категория, заказ → покупатель → товар → продавец), **Cypher с MATCH проще и нагляднее**: запрос читается как описание пути по графу. Postgres и Mongo лучше подходят для плоских таблиц/документов и сложной аналитики с окнами и множественными группировками.

---

## 7. Поиск общих соседей и сортировка по количеству общих связей

«Общие соседи» — узлы, связанные с обоими выбранными узлами. Ниже: пары товаров и число общих соседей (категория и/или продавец), отсортированные по убыванию этого числа.

```cypher
// Пары различных товаров: общие соседи = общая категория и/или общий продавец
MATCH (p1:Product)-[]->(common)<-[]-(p2:Product)
WHERE p1.productId < p2.productId
WITH p1, p2, count(DISTINCT common) AS commonNeighbors
WHERE commonNeighbors > 0
RETURN p1.name AS product1, p2.name AS product2, commonNeighbors
ORDER BY commonNeighbors DESC
LIMIT 20;
```

Вариант: только пары товаров с хотя бы одним общим соседом, с именами категорий/продавцов:

```cypher
MATCH (p1:Product)-[]->(common)<-[]-(p2:Product)
WHERE p1.productId < p2.productId
WITH p1, p2, collect(DISTINCT common) AS commonNodes, count(DISTINCT common) AS commonNeighbors
WHERE commonNeighbors > 0
RETURN p1.name AS product1, p2.name AS product2, commonNeighbors,
       [n IN commonNodes | coalesce(n.name, toString(n.userId))] AS commonNeighborNames
ORDER BY commonNeighbors DESC
LIMIT 20;
```

Если в графе появятся заказы (Customer)-[:ORDERED]->(Product), общие соседи двух товаров — покупатели, купившие оба; сортировка по количеству таких покупателей даст «часто покупают вместе».

---

## 8. Запрос: цепочки + агрегации + фильтрация

Пример комплексного запроса: по цепочке «категория → товары → продавец» отфильтровать категории и продавцов, посчитать агрегаты и отфильтровать результат.

```cypher
// Цепочка: Category -> Product -> Merchant.
// Агрегация: число товаров и число категорий на продавца.
// Фильтр: только продавцы с более чем одним товаром и только категории с названием не пустым.
MATCH (c:Category)<-[:IN_CATEGORY]-(p:Product)-[:SOLD_BY]->(u:User)
WHERE u.type = 'merchant' AND c.name IS NOT NULL AND trim(c.name) <> ''
WITH u, c, count(p) AS productsInCategory
WITH u, count(c) AS categoriesCount, sum(productsInCategory) AS totalProducts,
     collect({ category: c.name, products: productsInCategory }) AS byCategory
WHERE totalProducts > 1
RETURN u.name AS merchant_name, totalProducts, categoriesCount, byCategory
ORDER BY totalProducts DESC, categoriesCount DESC
LIMIT 15;
```

Кратко, что в запросе:
- **Цепочка:** Category ← Product → User (два типа связей в одном MATCH).
- **Агрегации:** `count(p)`, `count(c)`, `sum(productsInCategory)`, `collect(...)`.
- **Фильтрация:** по типу пользователя, по имени категории, по `totalProducts > 1`.

---

## Ответы на вопросы (п. 8)

### Какие задачи лучше решаются в Neo4j, нежели в Postgres/Mongo?

- **Обход связей и цепочек:** «все товары продавца», «все заказы покупателя», «товар → категория → другие товары той же категории» — один MATCH без перечисления JOIN по ключам.
- **Поиск общих соседей, рекомендации:** «товары, которые покупают вместе», «похожие продавцы по набору категорий» — естественно формулируются как обход графа и подсчёт общих узлов.
- **Короткие пути и степени связности:** «кратчайший путь между сущностями», «у кого больше всего общих покупателей с данным товаром» — графовая модель и индексы по связям дают преимущество.
- **Модели, где связи первичны:** соцсети, рекомендации, фрод-детекция по цепочкам транзакций — Neo4j удобнее реляционной и документной модели.

### Какие — хуже?

- **Сложная аналитика и окна:** оконные функции (RANK, скользящее среднее, процент от итога) и сложные GROUP BY — в Postgres реализуются проще и часто быстрее.
- **Массовые пакетные обновления:** большие объёмы плоских данных, ETL по таблицам — реляционная СУБД и документная модель обычно удобнее.
- **Жёсткая схема и отчёты:** отчёты по фиксированным таблицам с множеством измерений и агрегатов — SQL и агрегационные пайплайны Mongo заточены под это.
- **Транзакционная целостность на множестве сущностей:** сложные многотабличные транзакции с блокировками — традиционная реляционная СУБД часто предсказуемее.

### Где в вашем проекте логично и оправдано использовать Neo4j?

- **Рекомендации и «похожие товары»:** общие покупатели/категории/продавцы между товарами, «с этим товаром часто покупают» — граф и запросы общих соседей хорошо ложатся на Neo4j.
- **Анализ продавцов и категорий:** «какие категории охватывает продавец», «топ продавцов по числу категорий/товаров» при уже загруженном графе — удобно делать в Cypher рядом с основными сервисами.
- **Поиск цепочек для фрода/модерации:** если появятся связи между пользователями (например, рефералы, общие адреса), поиск подозрительных цепочек — типичная задача для графа.
- **Дополнение, а не замена:** основная модель маркетплейса (заказы, остатки, документы) остаётся в Postgres/Mongo; Neo4j — слой для сценариев «по связям и соседям», синхронизируемый с основными БД (как в вашем `migrate.sh`).

---

## Файл только с Cypher-запросами для копирования

Ниже — те же запросы в виде одного блока для выполнения в `cypher-shell` или Neo4j Browser.

```cypher
// === 6. Аналоги JOIN / $lookup ===
// Товары с продавцом и категорией (аналог 3 таблиц)
MATCH (g:Product)-[:SOLD_BY]->(u:User) MATCH (g)-[:IN_CATEGORY]->(c:Category)
RETURN g.productId, g.name AS product_name, u.name AS merchant_name, c.name AS category_name
ORDER BY category_name, product_name LIMIT 10;

// === 7. Общие соседи, сортировка по количеству ===
MATCH (p1:Product)-[]->(common)<-[]-(p2:Product)
WHERE p1.productId < p2.productId
WITH p1, p2, count(DISTINCT common) AS commonNeighbors
WHERE commonNeighbors > 0
RETURN p1.name AS product1, p2.name AS product2, commonNeighbors
ORDER BY commonNeighbors DESC LIMIT 20;

// === 8. Цепочка + агрегации + фильтрация ===
MATCH (c:Category)<-[:IN_CATEGORY]-(p:Product)-[:SOLD_BY]->(u:User)
WHERE u.type = 'merchant' AND c.name IS NOT NULL AND trim(c.name) <> ''
WITH u, c, count(p) AS productsInCategory
WITH u, count(c) AS categoriesCount, sum(productsInCategory) AS totalProducts,
     collect({ category: c.name, products: productsInCategory }) AS byCategory
WHERE totalProducts > 1
RETURN u.name AS merchant_name, totalProducts, categoriesCount, byCategory
ORDER BY totalProducts DESC, categoriesCount DESC LIMIT 15;
```
