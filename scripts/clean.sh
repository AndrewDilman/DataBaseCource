#!/bin/bash
set -e

echo "=== Очистка PostgreSQL и Neo4j ==="

echo "Очистка PostgreSQL..."
docker exec marketplace-db psql -U admin -d marketplace -c "
    TRUNCATE TABLE purchase_history, reviews, orders, goods, users, categories, addresses, pickup_points, warehouses CASCADE;
    ALTER SEQUENCE addresses_addr_id_seq RESTART WITH 1;
    ALTER SEQUENCE categories_caty_id_seq RESTART WITH 1;
    ALTER SEQUENCE users_user_id_seq RESTART WITH 1;
    ALTER SEQUENCE goods_good_id_seq RESTART WITH 1;
    ALTER SEQUENCE orders_id_seq RESTART WITH 1;
    ALTER SEQUENCE reviews_id_seq RESTART WITH 1;
    ALTER SEQUENCE purchase_history_id_seq RESTART WITH 1;
    ALTER SEQUENCE pickup_points_id_seq RESTART WITH 1;
    ALTER SEQUENCE warehouses_id_seq RESTART WITH 1;
" 2>/dev/null || echo "Таблицы не существуют или БД не готова"

echo "Очистка Neo4j..."
docker exec marketplace-neo4j cypher-shell -u neo4j -p 12345678 "MATCH (n) DETACH DELETE n;" 2>/dev/null || echo "Neo4j не готова"

echo "Очистка завершена!"