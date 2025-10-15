-- Включаем отображение времени выполнения запросов в psql
\timing on

-- Очистка существующих таблиц
DROP TABLE IF EXISTS test_logged CASCADE;
DROP TABLE IF EXISTS test_unlogged CASCADE;

-- 2. СОЗДАНИЕ ТАБЛИЦ И ИНДЕКСОВ

SELECT '--- 2. СОЗДАНИЕ ТАБЛИЦ (LOGGED и UNLOGGED) ---' AS test_info;

-- 2.1. LOGGED таблица (обычная)
CREATE TABLE test_logged (
    id BIGSERIAL PRIMARY KEY,
    data TEXT NOT NULL,
    num_value INTEGER NOT NULL
);

-- 2.2. UNLOGGED таблица (без WAL-журнала)
CREATE UNLOGGED TABLE test_unlogged (
    id BIGSERIAL PRIMARY KEY,
    data TEXT NOT NULL,
    num_value INTEGER NOT NULL
);

-- Создание индекса для честного сравнения SELECT/DELETE
CREATE INDEX idx_logged_num ON test_logged (num_value);
CREATE INDEX idx_unlogged_num ON test_unlogged (num_value);

-- 3. ЗАМЕРЫ НА ВСТАВКУ (INSERT)

-- Кейс 3.1: Вставка группой (Bulk Insert) - 100,000 записей за один запрос
SELECT '--- 3.1. BULK INSERT (100,000 записей) ---' AS test_info;

INSERT INTO test_logged (data, num_value)
SELECT
    'Logged Data ' || s::text,
    (s % 1000)
FROM generate_series(1, 100000) s;
SELECT 'LOGGED: Bulk Insert завершен.' AS status;

INSERT INTO test_unlogged (data, num_value)
SELECT
    'Unlogged Data ' || s::text,
    (s % 1000)
FROM generate_series(1, 100000) s;
SELECT 'UNLOGGED: Bulk Insert завершен.' AS status;

-- Кейс 3.2: Вставка по одной (Single Insert Simulation) - 10,000 транзакций
SELECT '--- 3.2. SINGLE INSERT (10,000 записей по одной) ---' AS test_info;

DO $$
BEGIN
    FOR i IN 1..10000 LOOP
        INSERT INTO test_logged (data, num_value) VALUES ('Single Logged ' || i, i % 100);
    END LOOP;
END $$;
SELECT 'LOGGED: Single Insert завершен.' AS status;

DO $$
BEGIN
    FOR i IN 1..10000 LOOP
        INSERT INTO test_unlogged (data, num_value) VALUES ('Single Unlogged ' || i, i % 100);
    END LOOP;
END $$;
SELECT 'UNLOGGED: Single Insert завершен.' AS status;

-- 4. ЗАМЕРЫ НА ЧТЕНИЕ (SELECT)

SELECT '--- 4. SELECT (Чтение по индексу) ---' AS test_info;

SELECT COUNT(*) FROM test_logged WHERE num_value = 50;
SELECT 'LOGGED: Select завершен.' AS status;

SELECT COUNT(*) FROM test_unlogged WHERE num_value = 50;
SELECT 'UNLOGGED: Select завершен.' AS status;

-- 5. ЗАМЕРЫ НА УДАЛЕНИЕ ГРУППОЙ (TRUNCATE)

SELECT '--- 5.1. BULK DELETE (TRUNCATE) ---' AS test_info;

TRUNCATE TABLE test_logged;
SELECT 'LOGGED: TRUNCATE завершен.' AS status;

TRUNCATE TABLE test_unlogged;
SELECT 'UNLOGGED: TRUNCATE завершен.' AS status;

-- 6. ПЕРЕЗАПОЛНЕНИЕ ДЛЯ ТЕСТА SINGLE DELETE

SELECT '--- 6. ПЕРЕЗАПОЛНЕНИЕ ДЛЯ ТЕСТА SINGLE DELETE (100,000 записей) ---' AS test_info;

INSERT INTO test_logged (data, num_value)
SELECT
    'Logged Data ' || s::text,
    (s % 1000)
FROM generate_series(1, 100000) s;

INSERT INTO test_unlogged (data, num_value)
SELECT
    'Unlogged Data ' || s::text,
    (s % 1000)
FROM generate_series(1, 100000) s;
SELECT 'Повторное заполнение завершено.' AS status;

-- 7. ЗАМЕРЫ НА УДАЛЕНИЕ ПО ОДНОЙ (SINGLE DELETE)

SELECT '--- 7.1. SINGLE DELETE (10,000 записей по одной) ---' AS test_info;

DO $$
BEGIN
    FOR i IN 1..10000 LOOP
        DELETE FROM test_logged WHERE id = i;
    END LOOP;
END $$;
SELECT 'LOGGED: Single Delete завершен.' AS status;

DO $$
BEGIN
    FOR i IN 1..10000 LOOP
        DELETE FROM test_unlogged WHERE id = i;
    END LOOP;
END $$;
SELECT 'UNLOGGED: Single Delete завершен.' AS status;

-- 8. ЗАВЕРШЕНИЕ
\timing off
DROP TABLE IF EXISTS test_logged CASCADE;
DROP TABLE IF EXISTS test_unlogged CASCADE;
SELECT '--- ТЕСТЫ ЗАВЕРШЕНЫ. ---' AS test_info;
