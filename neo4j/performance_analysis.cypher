// 7. Анализ производительности с использованием PROFILE и EXPLAIN

// 7.1 Пример использования EXPLAIN для просмотра плана выполнения запроса (без его выполнения)
EXPLAIN
MATCH (p:Product)-[:IN_CATEGORY]->(c:Category)
WHERE c.name CONTAINS 'Tech'
RETURN p.name, c.name
ORDER BY p.name
LIMIT 10;

// 7.2 Пример использования PROFILE для анализа реального выполнения запроса
PROFILE
MATCH (u:User {type: 'merchant'})<-[:SOLD_BY]-(p:Product)-[:IN_CATEGORY]->(c:Category)
RETURN u.name, count(p) AS productCount, collect(c.name)[0..3] AS categories
ORDER BY productCount DESC
LIMIT 5;

// 7.3 Анализ сложного запроса с агрегацией и фильтрацией
PROFILE
MATCH (c:Category)<-[:IN_CATEGORY]-(p:Product)-[:SOLD_BY]->(u:User)
WHERE u.type = 'merchant' AND c.name IS NOT NULL AND trim(c.name) <> ''
WITH u, c, count(p) AS productsInCategory
WITH u, count(c) AS categoriesCount, sum(productsInCategory) AS totalProducts,
     collect({ category: c.name, products: productsInCategory }) AS byCategory
WHERE totalProducts > 1
RETURN u.name AS merchant_name, totalProducts, categoriesCount, byCategory
ORDER BY totalProducts DESC, categoriesCount DESC
LIMIT 15;

// 7.4 Поиск общих соседей с анализом производительности
PROFILE
MATCH (p1:Product)-[]->(common)<-[]-(p2:Product)
WHERE p1.productId < p2.productId
WITH p1, p2, count(DISTINCT common) AS commonNeighbors
WHERE commonNeighbors > 0
RETURN p1.name AS product1, p2.name AS product2, commonNeighbors
ORDER BY commonNeighbors DESC
LIMIT 20;

// 7.5 Простой запрос с индексом (предполагая, что индексы созданы)
PROFILE
MATCH (u:User)
WHERE u.userId = 123
RETURN u.name, u.type;

// 7.6 Запрос с использованием индекса для поиска по имени
PROFILE
MATCH (c:Category)
WHERE c.name = 'Electronics'
RETURN c.categoryId, c.name;