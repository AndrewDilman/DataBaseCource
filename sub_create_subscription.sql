-- Устанавливаем расширение dblink
CREATE EXTENSION IF NOT EXISTS dblink;

-- Ждем пока основной PostgreSQL станет доступным
DO $$
DECLARE
    retries INTEGER := 30;
    delay INTERVAL := '5 seconds';
BEGIN
    FOR i IN 1..retries LOOP
        BEGIN
            -- Пытаемся подключиться к публикатору (используем порт 5432 внутри сети Docker)
            PERFORM dblink_connect('host=postgres port=5432 dbname=marketplace user=admin password=123');
            RAISE NOTICE 'Successfully connected to publisher at attempt %', i;
            PERFORM dblink_disconnect();
            EXIT;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Attempt %: Publisher not ready yet, waiting...', i;
                PERFORM pg_sleep(EXTRACT(EPOCH FROM delay));
                
                IF i = retries THEN
                    RAISE EXCEPTION 'Failed to connect to publisher after % attempts', retries;
                END IF;
        END;
    END LOOP;
END $$;

-- Убедимся, что публикация существует на основном сервере
DO $$
BEGIN
    PERFORM dblink_connect('host=postgres port=5432 dbname=marketplace user=admin password=123');
    
    IF NOT (SELECT EXISTS (
        SELECT 1 FROM dblink(
            'host=postgres port=5432 dbname=marketplace user=admin password=123',
            'SELECT 1 FROM pg_publication WHERE pubname = ''marketplace_all_tables'''
        ) AS t(exists boolean)
    )) THEN
        RAISE EXCEPTION 'Publication marketplace_all_tables does not exist on publisher';
    END IF;
    
    PERFORM dblink_disconnect();
END $$;

-- Удалим подписку, если существует
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_subscription WHERE subname = 'marketplace_all_tables_sub') THEN
        DROP SUBSCRIPTION marketplace_all_tables_sub;
        RAISE NOTICE 'Dropped existing subscription';
    END IF;
END $$;

-- Создаём подписку (используем порт 5432 внутри сети Docker)
CREATE SUBSCRIPTION marketplace_all_tables_sub
CONNECTION 'host=postgres port=5432 dbname=marketplace user=admin password=123'
PUBLICATION marketplace_all_tables
WITH (
    copy_data = true,
    create_slot = true,
    enabled = true
);

-- Выводим уведомление о успешном создании
DO $$
BEGIN
    RAISE NOTICE 'Subscription marketplace_all_tables_sub created successfully';
END $$;

-- Проверяем статус репликации
DO $$
BEGIN
    RAISE NOTICE 'Subscription status:';
END $$;

SELECT * FROM pg_stat_subscription;