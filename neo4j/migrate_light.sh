#!/bin/bash
set -e

echo "=== PostgreSQL → Neo4j Миграция (light) ==="

echo "Ожидание PostgreSQL..."
until docker exec marketplace-db pg_isready -U admin 2>/dev/null; do
  sleep 2
done
echo "PostgreSQL готов."

echo "Ожидание Neo4j..."
until docker exec marketplace-neo4j cypher-shell -u neo4j -p 12345678 "RETURN 1" 2>/dev/null; do
  sleep 5
done
echo "Neo4j готов."

echo "Создание папки для экспорта..."
docker exec marketplace-db mkdir -p /tmp/neo4j_export

echo "Экспорт категорий..."
docker exec marketplace-db psql -U admin -d marketplace -c "\copy categories TO '/tmp/neo4j_export/categories.csv' WITH CSV HEADER;"

echo "Экспорт покупателей..."
docker exec marketplace-db psql -U admin -d marketplace -c "\copy (SELECT user_id, name, user_type FROM users WHERE user_type = 'customer') TO '/tmp/neo4j_export/customers.csv' WITH CSV HEADER;"

echo "Экспорт продавцов..."
docker exec marketplace-db psql -U admin -d marketplace -c "\copy (SELECT user_id, name, user_type FROM users WHERE user_type = 'merchant') TO '/tmp/neo4j_export/merchants.csv' WITH CSV HEADER;"

echo "Экспорт товаров..."
docker exec marketplace-db psql -U admin -d marketplace -c "\copy (SELECT good_id, name, merch_id, caty_id FROM goods) TO '/tmp/neo4j_export/goods.csv' WITH CSV HEADER;"

echo "Экспорт заказов..."
docker exec marketplace-db psql -U admin -d marketplace -c "\copy (SELECT user_id, good_id, COUNT(*) as cnt FROM orders GROUP BY user_id, good_id) TO '/tmp/neo4j_export/orders.csv' WITH CSV HEADER;"

echo "Экспорт отзывов..."
docker exec marketplace-db psql -U admin -d marketplace -c "\copy reviews TO '/tmp/neo4j_export/reviews.csv' WITH CSV HEADER;"

echo "Копирование CSV в Neo4j..."
docker cp marketplace-db:/tmp/neo4j_export/. /tmp/neo4j_import/
docker cp /tmp/neo4j_import/. marketplace-neo4j:/var/lib/neo4j/import/

echo "Создание ограничений..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
CREATE CONSTRAINT IF NOT EXISTS FOR (u:User) REQUIRE u.userId IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (p:Product) REQUIRE p.productId IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (c:Category) REQUIRE c.categoryId IS UNIQUE;
EOF

echo "Загрузка категорий..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
LOAD CSV WITH HEADERS FROM 'file:///categories.csv' AS row
MERGE (c:Category {categoryId: toInteger(row.caty_id)})
SET c.name = row.name;
EOF

echo "Загрузка пользователей..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
LOAD CSV WITH HEADERS FROM 'file:///customers.csv' AS row
MERGE (u:User {userId: toInteger(row.user_id)})
SET u.name = row.name, u.type = 'customer';

LOAD CSV WITH HEADERS FROM 'file:///merchants.csv' AS row
MERGE (u:User {userId: toInteger(row.user_id)})
SET u.name = row.name, u.type = 'merchant';
EOF

echo "Загрузка товаров..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
LOAD CSV WITH HEADERS FROM 'file:///goods.csv' AS row
MERGE (p:Product {productId: toInteger(row.good_id)})
SET p.name = row.name,
    p.merchantId = toInteger(row.merch_id),
    p.categoryId = toInteger(row.caty_id);
EOF

echo "Создание связей SOLD_BY..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
LOAD CSV WITH HEADERS FROM 'file:///goods.csv' AS row
MATCH (p:Product {productId: toInteger(row.good_id)})
MATCH (u:User {userId: toInteger(row.merch_id)})
MERGE (p)-[:SOLD_BY]->(u);
EOF

echo "Создание связей IN_CATEGORY..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
LOAD CSV WITH HEADERS FROM 'file:///goods.csv' AS row
MATCH (p:Product {productId: toInteger(row.good_id)})
MATCH (c:Category {categoryId: toInteger(row.caty_id)})
MERGE (p)-[:IN_CATEGORY]->(c);
EOF

echo "Создание связей BOUGHT..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
LOAD CSV WITH HEADERS FROM 'file:///orders.csv' AS row
MATCH (u:User {userId: toInteger(row.user_id)})
MATCH (p:Product {productId: toInteger(row.good_id)})
MERGE (u)-[b:BOUGHT]->(p)
SET b.count = toInteger(row.cnt);
EOF

echo "Создание связей REVIEWED..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
LOAD CSV WITH HEADERS FROM 'file:///reviews.csv' AS row
MATCH (u:User {userId: toInteger(row.user_id)})
MATCH (p:Product {productId: toInteger(row.good_id)})
MERGE (u)-[r:REVIEWED]->(p)
SET r.rating = toInteger(row.rating),
    r.comment = row.comment;
EOF

echo "Миграция завершена!"