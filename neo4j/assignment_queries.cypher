// ============================================================
// Задание 6: Аналоги Postgres JOIN / Mongo $lookup на Cypher MATCH
// ============================================================

// 6.1 Товары с продавцом и категорией (аналог 3 таблиц JOIN)
MATCH (g:Product)-[:SOLD_BY]->(u:User)
MATCH (g)-[:IN_CATEGORY]->(c:Category)
RETURN g.productId AS good_id, g.name AS product_name, u.name AS merchant_name, c.name AS category_name
ORDER BY category_name, product_name
LIMIT 10;

// 6.2 Товары с отзывами и средним рейтингом (при наличии связи REVIEWED с свойством rating)
// OPTIONAL MATCH (u:User)-[rev:REVIEWED]->(g:Product)
// WITH g, count(rev) AS reviewCount, avg(rev.rating) AS avgRating
// RETURN g.productId, g.name, reviewCount, round(avgRating * 100) / 100 AS avgRating
// ORDER BY avgRating DESC, reviewCount DESC LIMIT 20;


// ============================================================
// Задание 7: Поиск общих соседей, сортировка по количеству связей
// ============================================================

// Пары товаров и число общих соседей (категория и/или продавец)
MATCH (p1:Product)-[]->(common)<-[]-(p2:Product)
WHERE p1.productId < p2.productId
WITH p1, p2, count(DISTINCT common) AS commonNeighbors
WHERE commonNeighbors > 0
RETURN p1.name AS product1, p2.name AS product2, commonNeighbors
ORDER BY commonNeighbors DESC
LIMIT 20;


// ============================================================
// Задание 8: Цепочка + агрегации + фильтрация
// ============================================================

// Категория -> Товары -> Продавец: агрегаты по продавцу, фильтр по числу товаров
MATCH (c:Category)<-[:IN_CATEGORY]-(p:Product)-[:SOLD_BY]->(u:User)
WHERE u.type = 'merchant' AND c.name IS NOT NULL AND trim(c.name) <> ''
WITH u, c, count(p) AS productsInCategory
WITH u, count(c) AS categoriesCount, sum(productsInCategory) AS totalProducts,
     collect( { category: c.name, products: productsInCategory } ) AS byCategory
WHERE totalProducts > 1
RETURN u.name AS merchant_name, totalProducts, categoriesCount, byCategory
ORDER BY totalProducts DESC, categoriesCount DESC
LIMIT 15;
