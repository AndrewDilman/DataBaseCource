// 1. Создаем узлы ПОЛЬЗОВАТЕЛИ (упрощенный вариант)
CALL apoc.load.jdbc('jdbc:postgresql://postgres:5432/marketplace?user=admin&password=123', 
    'SELECT user_id, name, user_type FROM users WHERE user_type = \'customer\' LIMIT 10'
) YIELD row
MERGE (u:User {
    userId: row.user_id,
    name: row.name,
    type: row.user_type
});

// 2. Создаем узлы ПРОДАВЦЫ отдельно
CALL apoc.load.jdbc('jdbc:postgresql://postgres:5432/marketplace?user=admin&password=123',
    'SELECT user_id, name, user_type FROM users WHERE user_type = \'merchant\' LIMIT 5'
) YIELD row
MERGE (u:User {
    userId: row.user_id,
    name: row.name,
    type: row.user_type
});

// 3. Создаем узлы КАТЕГОРИИ
CALL apoc.load.jdbc('jdbc:postgresql://postgres:5432/marketplace?user=admin&password=123',
    'SELECT caty_id, name FROM categories'
) YIELD row
MERGE (c:Category {
    categoryId: row.caty_id,
    name: row.name
});

// 4. Создаем узлы ТОВАРЫ
CALL apoc.load.jdbc('jdbc:postgresql://postgres:5432/marketplace?user=admin&password=123',
    'SELECT good_id, name, merch_id, caty_id FROM goods LIMIT 20'
) YIELD row
MERGE (p:Product {
    productId: row.good_id,
    name: row.name,
    merchantId: row.merch_id,
    categoryId: row.caty_id
});

// 5. Создаем связи ТОВАР → ПРОДАВЕЦ
MATCH (p:Product)
MATCH (u:User {userId: p.merchantId, type: 'merchant'})
MERGE (p)-[:SOLD_BY]->(u);

// 6. Создаем связи ТОВАР → КАТЕГОРИЯ  
MATCH (p:Product)
MATCH (c:Category {categoryId: p.categoryId})
MERGE (p)-[:IN_CATEGORY]->(c);