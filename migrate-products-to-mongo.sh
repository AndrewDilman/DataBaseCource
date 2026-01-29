#!/bin/bash

echo "=== Миграция через mongoimport ==="

# Ждём БД
until pg_isready -h postgres -p 5432 -U admin -d marketplace; do sleep 2; done
until mongosh --host mongodb --port 27017 -u admin -p 123 \
  --authenticationDatabase admin --eval "db.runCommand({ping: 1})" > /dev/null 2>&1; do
  sleep 2
done

echo "Очищаем коллекцию..."
mongosh --host mongodb --port 27017 -u admin -p 123 \
  --authenticationDatabase admin \
  --eval 'db = db.getSiblingDB("marketplace"); db.products.drop()'

echo "Экспортируем в JSON..."
PGPASSWORD=123 psql -h postgres -p 5432 -U admin -d marketplace -t -A \
  -c "SELECT 
        json_build_object(
          'good_id', g.good_id,
          'name', g.name,
          'merchant_id', g.merch_id,
          'category_id', g.caty_id,
          'merchant_name', u.name,
          'category_name', c.name,
          'attributes', '{}'::json,
          'tags', '[]'::json,
          'created_at', CURRENT_TIMESTAMP,
          'updated_at', CURRENT_TIMESTAMP
        )
      FROM goods g
      JOIN users u ON g.merch_id = u.user_id
      JOIN categories c ON g.caty_id = c.caty_id" \
  -o /tmp/products.json

echo "Преобразуем в корректный JSON-массив..."
echo '[' > /tmp/products_array.json
sed '2,$s/^/,/' /tmp/products.json >> /tmp/products_array.json
echo ']' >> /tmp/products_array.json

echo "Импортируем через mongoimport..."
mongoimport --host mongodb --port 27017 -u admin -p 123 \
  --authenticationDatabase admin \
  --db marketplace --collection products \
  --file /tmp/products_array.json --jsonArray

echo "Создаем индексы..."
mongosh --host mongodb --port 27017 -u admin -p 123 \
  --authenticationDatabase admin <<'EOF'
db = db.getSiblingDB("marketplace");
db.products.createIndex({ good_id: 1 }, { unique: true });
db.products.createIndex({ merchant_id: 1 });
db.products.createIndex({ category_id: 1 });
EOF

echo "Готово! Перенесено:"
mongosh --host mongodb --port 27017 -u admin -p 123 \
  --authenticationDatabase admin \
  --eval 'db = db.getSiblingDB("marketplace"); db.products.countDocuments();'