#!/bin/bash

# Скрипт для настройки репликации после запуска контейнеров

echo "Ожидание запуска основной базы данных..."
sleep 60

# Проверяем, готова ли основная база данных
echo "Проверка готовности основной базы данных..."
for i in {1..30}; do
  if docker exec marketplace-db pg_isready > /dev/null 2>&1; then
    echo "Основная база данных готова"
    break
  else
    echo "Ожидание готовности основной базы данных... ($i/30)"
    sleep 10
  fi
done

# Создаем подписку вручную
echo "Создание подписки на репликацию..."
docker exec marketplace-subscriber psql -U admin -d marketplace -c "
SELECT 'Подписка уже существует' WHERE EXISTS (SELECT 1 FROM pg_subscription WHERE subname = 'marketplace_all_tables_sub');

DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_subscription WHERE subname = 'marketplace_all_tables_sub') THEN
        CREATE SUBSCRIPTION marketplace_all_tables_sub
        CONNECTION 'host=postgres port=5432 dbname=marketplace user=admin password=123'
        PUBLICATION marketplace_all_tables
        WITH (
            copy_data = true,
            create_slot = true,
            enabled = true
        );
        RAISE NOTICE 'Подписка успешно создана';
    END IF;
END
\$\$;
"

echo "Настройка репликации завершена"
