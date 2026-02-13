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