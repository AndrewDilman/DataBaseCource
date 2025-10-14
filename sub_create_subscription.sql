-- Создание подписки на логическую публикацию с primary
-- Этот скрипт выполняется на контейнере postgres_subscriber
-- Требует доступности primary по сети как хоста "postgres" (имя сервиса в Compose)

-- Удалим подписку, если существует (для идемпотентности при перезапусках)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_subscription WHERE subname = 'marketplace_all_tables_sub') THEN
        EXECUTE 'DROP SUBSCRIPTION marketplace_all_tables_sub';
    END IF;
END $$;

-- Создаём подписку, копируем исторические данные (copy_data = true)
CREATE SUBSCRIPTION marketplace_all_tables_sub
CONNECTION 'host=postgres port=5432 dbname=marketplace user=admin password=123'
PUBLICATION marketplace_all_tables
WITH (
    copy_data = true,
    create_slot = true,
    enabled = true
);


