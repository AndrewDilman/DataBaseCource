
echo "=== 1. Проверка связи данных PostgreSQL ↔ MongoDB ==="
echo "PostgreSQL (базовые данные товара good_id=1):"
docker exec marketplace-db psql -U admin -d marketplace -c "SELECT g.good_id, g.name, u.name as merchant, c.name as category FROM goods g JOIN users u ON g.merch_id = u.user_id JOIN categories c ON g.caty_id = c.caty_id WHERE g.good_id = 123 LIMIT 1;"
echo ""
echo "MongoDB (полные данные товара good_id=1):"
docker exec marketplace-mongodb mongosh -u admin -p 123 --authenticationDatabase admin --eval 'db = db.getSiblingDB("marketplace"); db.products.findOne({ good_id: 123 }, { name: 1, merchant_name: 1, category_name: 1, attributes: 1, tags: 1 });'
echo ""

============================================================================
# 1. Текущие подключения к MongoDB
mongodb_connections_current

# 2. Операции в секунду (чтение/запись)
rate(mongodb_opcounters_total[5m])

# 3. Использование памяти
mongodb_memory_usage_bytes

# 4. Количество документов в коллекции products
mongodb_collection_documents_total{collection="products"}

# 5. Размер коллекции products
mongodb_collection_size_bytes{collection="products"}

# 6. Запросы к коллекции products в секунду
rate(mongodb_collection_query_total{collection="products"}[5m])

# 7. Кэш попадания
mongodb_cache_utilization

# 8. Активные транзакции
mongodb_transactions_current

# 9. Проверка что экспортер жив
up{job="mongodb-exporter"}

# 10. Все метрики MongoDB
{mongodb!=""}