-- Заглушка для подписки
-- Реальная подписка будет создана с помощью скрипта setup_replication.sh
-- после запуска контейнеров, когда основная база данных будет готова
-- и сможет принимать подключения для создания подписки

-- Удалим подписку, если существует (для идемпотентности при перезапусках)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_subscription WHERE subname = 'marketplace_all_tables_sub') THEN
        EXECUTE 'DROP SUBSCRIPTION IF EXISTS marketplace_all_tables_sub';
    END IF;
END $$;

-- Выводим информационное сообщение
DO $$
BEGIN
    RAISE NOTICE 'Подписка будет создана отдельно с помощью скрипта setup_replication.sh';
END $$;
