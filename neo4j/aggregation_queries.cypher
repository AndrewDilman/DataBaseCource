// 5. Агрегационные запросы (count, collect) с сортировкой и ограничением

// 5.1 Подсчет количества узлов каждого типа
MATCH (n)
RETURN labels(n) AS nodeType, count(n) AS count
ORDER BY count DESC;

// 5.2 Количество товаров по категориям
MATCH (p:Product)-[:IN_CATEGORY]->(c:Category)
RETURN c.name AS categoryName, count(p) AS productCount
ORDER BY productCount DESC
LIMIT 10;

// 5.3 Среднее количество товаров на продавца
MATCH (u:User {type: 'merchant'})<-[:SOLD_BY]-(p:Product)
WITH u, count(p) AS productCount
RETURN avg(productCount) AS avgProductsPerMerchant,
       collect({merchant: u.name, productCount: productCount})[0..5] AS sampleMerchants
ORDER BY avgProductsPerMerchant DESC;

// 5.4 Коллекция всех товаров по категориям
MATCH (p:Product)-[:IN_CATEGORY]->(c:Category)
RETURN c.name AS category, 
       collect(p.name)[0..10] AS products,
       count(p) AS totalProducts
ORDER BY totalProducts DESC
LIMIT 5;

// 5.5 Подсчет связей у каждого пользователя
MATCH (u:User)-[r]-(connected)
RETURN u.name AS userName, 
       u.type AS userType,
       count(r) AS connectionCount,
       collect(type(r)) AS relationshipTypes
ORDER BY connectionCount DESC
LIMIT 10;

// 5.6 Статистика по типам пользователей
MATCH (u:User)
RETURN u.type AS userType, 
       count(u) AS userCount,
       count{ (u)-[:SOLD_BY]->() } AS sellerConnections,
       count{ (u)<-[:SOLD_BY]-() } AS buyerConnections
ORDER BY userCount DESC;


==============================================================

// Собираем категории для каждого продавца
MATCH (m1:User {type: 'merchant'})-[:SOLD_BY]-(p:Product)-[:IN_CATEGORY]->(c:Category)
WITH m1, COLLECT(DISTINCT c.categoryId) AS cats1
WHERE SIZE(cats1) > 0   // исключаем продавцов без товаров

// Для каждого продавца ищем других продавцов
MATCH (m2:User {type: 'merchant'})-[:SOLD_BY]-(p2:Product)-[:IN_CATEGORY]->(c2:Category)
WHERE m1 <> m2
WITH m1, cats1, m2, COLLECT(DISTINCT c2.categoryId) AS cats2
WHERE SIZE(cats2) > 0

// Вычисляем пересечение и объединение
WITH m1, m2,
     SIZE([x IN cats1 WHERE x IN cats2]) AS intersection,
     cats1, cats2
WITH m1, m2, intersection,
     SIZE(cats1) + SIZE(cats2) - intersection AS union
WHERE union > 0

// Возвращаем результат с сортировкой по убыванию сходства
RETURN m1.name AS seller1,
       m2.name AS seller2,
       intersection AS commonCategories,
       union AS totalCategories,
       (intersection * 1.0 / union) AS similarity
ORDER BY similarity DESC, intersection DESC
LIMIT 10;