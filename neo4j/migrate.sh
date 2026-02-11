#!/bin/bash
set -e

echo "=== Миграция PostgreSQL → Neo4j через CSV ==="

# --- Ожидание PostgreSQL ---
echo "Ожидание PostgreSQL..."
until docker exec marketplace-db pg_isready -U admin; do
  sleep 2
done
echo "PostgreSQL готов."

# --- Ожидание Neo4j ---
echo "Ожидание Neo4j..."
until docker exec marketplace-neo4j cypher-shell -u neo4j -p 12345678 "RETURN 1" > /dev/null 2>&1; do
  echo "Ожидание Neo4j..."
  sleep 5
done
echo "Neo4j готов."

# --- Создаём папку для CSV внутри PostgreSQL ---
docker exec marketplace-db mkdir -p /tmp/neo4j_export

# --- Экспорт таблиц в CSV с помощью \copy ---
echo "Экспорт пользователей (покупатели)..."
docker exec marketplace-db psql -U admin -d marketplace -c "\copy (SELECT user_id, name, user_type FROM users WHERE user_type = 'customer') TO '/tmp/neo4j_export/customers.csv' WITH CSV HEADER;"

echo "Экспорт продавцов..."
docker exec marketplace-db psql -U admin -d marketplace -c "\copy (SELECT user_id, name, user_type FROM users WHERE user_type = 'merchant') TO '/tmp/neo4j_export/merchants.csv' WITH CSV HEADER;"

echo "Экспорт категорий..."
docker exec marketplace-db psql -U admin -d marketplace -c "\copy (SELECT caty_id, name FROM categories) TO '/tmp/neo4j_export/categories.csv' WITH CSV HEADER;"

echo "Экспорт товаров..."
docker exec marketplace-db psql -U admin -d marketplace -c "\copy (SELECT good_id, name, merch_id, caty_id FROM goods) TO '/tmp/neo4j_export/goods.csv' WITH CSV HEADER;"

# --- Копирование CSV в Neo4j ---
echo "Копирование CSV в Neo4j..."
docker cp marketplace-db:/tmp/neo4j_export/. /tmp/neo4j_import/
docker cp /tmp/neo4j_import/. marketplace-neo4j:/var/lib/neo4j/import/

# --- Загрузка в Neo4j (ПАКЕТНАЯ ОБРАБОТКА) ---
echo "Загрузка пользователей (покупатели и продавцы) ..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
LOAD CSV WITH HEADERS FROM 'file:///customers.csv' AS row
CALL {
    WITH row
    CREATE (u:User {userId: toInteger(row.user_id)})
    SET u.name = row.name, u.type = row.user_type
} IN TRANSACTIONS OF 5000 ROWS;

LOAD CSV WITH HEADERS FROM 'file:///merchants.csv' AS row
CALL {
    WITH row
    CREATE (u:User {userId: toInteger(row.user_id)})
    SET u.name = row.name, u.type = row.user_type
} IN TRANSACTIONS OF 5000 ROWS;
EOF

echo "Загрузка категорий..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
LOAD CSV WITH HEADERS FROM 'file:///categories.csv' AS row
CALL {
    WITH row
    MERGE (c:Category {categoryId: toInteger(row.caty_id)})
    SET c.name = row.name
} IN TRANSACTIONS OF 1000 ROWS;
EOF

echo "Загрузка товаров (этап 1: создание узлов Product) ..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
LOAD CSV WITH HEADERS FROM 'file:///goods.csv' AS row
CALL {
    WITH row
    CREATE (p:Product {productId: toInteger(row.good_id)})
    SET p.name = row.name,
        p.merchantId = toInteger(row.merch_id),
        p.categoryId = toInteger(row.caty_id)
} IN TRANSACTIONS OF 5000 ROWS;
EOF

# --- 2. СОЗДАНИЕ ИНДЕКСОВ (для быстрого поиска) ---

echo "Создание индексов..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
CREATE INDEX IF NOT EXISTS FOR (u:User) ON (u.userId);
CREATE INDEX IF NOT EXISTS FOR (p:Product) ON (p.productId);
CREATE INDEX IF NOT EXISTS FOR (c:Category) ON (c.categoryId);
EOF

# --- 3. ОЖИДАНИЕ ГОТОВНОСТИ ВСЕХ ИНДЕКСОВ ---
echo "Ожидание готовности индексов..."
docker exec marketplace-neo4j cypher-shell -u neo4j -p 12345678 "CALL db.awaitIndexes(120);"
echo "Индексы готовы."

echo "Загрузка связей SOLD_BY (товар → продавец) ..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
LOAD CSV WITH HEADERS FROM 'file:///goods.csv' AS row
CALL {
    WITH row
    MATCH (p:Product {productId: toInteger(row.good_id)})
    MATCH (u:User {userId: toInteger(row.merch_id)})
    CREATE (p)-[:SOLD_BY]->(u)
} IN TRANSACTIONS OF 5000 ROWS;
EOF

echo "Загрузка связей IN_CATEGORY (товар → категория) ..."
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 <<'EOF'
LOAD CSV WITH HEADERS FROM 'file:///goods.csv' AS row
CALL {
    WITH row
    MATCH (p:Product {productId: toInteger(row.good_id)})
    MATCH (c:Category {categoryId: toInteger(row.caty_id)})
    CREATE (p)-[:IN_CATEGORY]->(c)
} IN TRANSACTIONS OF 5000 ROWS;
EOF

echo "Миграция завершена!"