#!/bin/bash
set -e

echo "=== Запуск легкого варианта (light) ==="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "1. Очистка БД..."
bash "$SCRIPT_DIR/clean.sh"

echo "2. Генерация данных в PostgreSQL..."
docker cp "$SCRIPT_DIR/generate_light.sql" marketplace-db:/generate_light.sql
docker exec marketplace-db psql -U admin -d marketplace -f /generate_light.sql
docker exec marketplace-db rm -f /generate_light.sql

echo "3. Миграция данных в Neo4j..."
bash "$PROJECT_DIR/neo4j/migrate_light.sh"

echo "Проверка результатов..."
echo ""
echo "=== PostgreSQL ==="
docker exec marketplace-db psql -U admin -d marketplace -c "
    SELECT 'Продавцы: ' || COUNT(*) FROM users WHERE user_type = 'merchant';
    SELECT 'Покупатели: ' || COUNT(*) FROM userS WHERE user_type = 'customer';
    SELECT 'Товары: ' || COUNT(*) FROM goods;
    SELECT 'Заказы: ' || COUNT(*) FROM orders;
    SELECT 'Отзывы: ' || COUNT(*) FROM reviews;
"

echo ""
echo "=== Neo4j ==="
docker exec marketplace-neo4j cypher-shell -u neo4j -p 12345678 "
    MATCH (u:User) RETURN 'Users: ' || COUNT(*) AS count
    UNION ALL MATCH (p:Product) RETURN 'Products: ' || COUNT(*) AS count
    UNION ALL MATCH (c:Category) RETURN 'Categories: ' || COUNT(*) AS count;
"

echo ""
echo "Готово!"