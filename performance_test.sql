-- 1. НАСТРОЙКА: Включение замера времени и очистка

-- Включаем отображение времени выполнения запросов
\timing on

-- Очистка существующих таблиц (если они есть)
DROP TABLE IF EXISTS test_logged CASCADE;
DROP TABLE IF EXISTS test_unlogged CASCADE;

-- 2. СОЗДАНИЕ ТАБЛИЦ И ИНДЕКСОВ

-- 2.1. LOGGED таблица (обычная)
CREATE TABLE test_logged (
    id BIGSERIAL PRIMARY KEY,
    data TEXT NOT NULL,
    num_value INTEGER NOT NULL -- Используется для индексации и выбора
);

-- 2.2. UNLOGGED таблица (без WAL-журнала)
CREATE UNLOGGED TABLE test_unlogged (
    id BIGSERIAL PRIMARY KEY,
    data TEXT NOT NULL,
    num_value INTEGER NOT NULL
);

-- Создание индекса для честного сравнения операций SELECT/DELETE
CREATE INDEX idx_logged_num ON test_logged (num_value);
CREATE INDEX idx_unlogged_num ON test_unlogged (num_value);

-- 3. ЗАМЕРЫ НА ВСТАВКУ (INSERT)

-- Кейс 3.1: Вставка группой (Bulk Insert) - 100,000 записей за один запрос
SELECT '--- 3.1. BULK INSERT (100,000 записей) ---' AS test_info;

-- LOGGED: Вставка
INSERT INTO test_logged (data, num_value)
SELECT
    'Logged Data ' || s::text,
    (s % 1000)
FROM generate_series(1, 100000) s;
SELECT 'LOGGED: Bulk Insert завершен.' AS status;

-- UNLOGGED: Вставка
INSERT INTO test_unlogged (data, num_value)
SELECT
    'Unlogged Data ' || s::text,
    (s % 1000)
FROM generate_series(1, 100000) s;
SELECT 'UNLOGGED: Bulk Insert завершен.' AS status;

-- Кейс 3.2: Вставка по одной (Single Insert Simulation) - 10,000 транзакций
-- Выполняется в блоке DO для имитации множества маленьких транзакций
SELECT '--- 3.2. SINGLE INSERT (10,000 записей по одной) ---' AS test_info;

-- LOGGED: Вставка по одной
DO $$
BEGIN
    FOR i IN 1..10000 LOOP
        INSERT INTO test_logged (data, num_value) VALUES ('Single Logged ' || i, i % 100);
    END LOOP;
END $$;
SELECT 'LOGGED: Single Insert завершен.' AS status;

-- UNLOGGED: Вставка по одной
DO $$
BEGIN
    FOR i IN 1..10000 LOOP
        INSERT INTO test_unlogged (data, num_value) VALUES ('Single Unlogged ' || i, i % 100);
    END LOOP;
END $$;
SELECT 'UNLOGGED: Single Insert завершен.' AS status;

-- 4. ЗАМЕРЫ НА ЧТЕНИЕ (SELECT)

-- Чтение по индексу (должно быть сравнимо)
SELECT '--- 4. SELECT (Чтение по индексу) ---' AS test_info;

-- LOGGED: Indexed SELECT
SELECT COUNT(*) FROM test_logged WHERE num_value = 50;
SELECT 'LOGGED: Select завершен.' AS status;

-- UNLOGGED: Indexed SELECT
SELECT COUNT(*) FROM test_unlogged WHERE num_value = 50;
SELECT 'UNLOGGED: Select завершен.' AS status;


-- 5. ЗАМЕРЫ НА УДАЛЕНИЕ ГРУППОЙ (TRUNCATE)

-- Кейс 5.1: Полное удаление (TRUNCATE)
-- Эта операция наглядно демонстрирует разницу из-за WAL
SELECT '--- 5.1. BULK DELETE (TRUNCATE) ---' AS test_info;

-- LOGGED: TRUNCATE
TRUNCATE TABLE test_logged;
SELECT 'LOGGED: TRUNCATE завершен.' AS status;

-- UNLOGGED: TRUNCATE
TRUNCATE TABLE test_unlogged;
SELECT 'UNLOGGED: TRUNCATE завершен.' AS status;

-- 6. ПОДГОТОВКА ДАННЫХ ДЛЯ ТЕСТА УДАЛЕНИЯ ПО ОДНОЙ

-- Необходимо снова заполнить таблицы, чтобы было что удалять
SELECT '--- 6. ПЕРЕЗАПОЛНЕНИЕ ДЛЯ ТЕСТА SINGLE DELETE (100,000 записей) ---' AS test_info;

INSERT INTO test_logged (data, num_value)
SELECT
    'Logged Data ' || s::text,
    (s % 1000)
FROM generate_series(1, 100000) s;
SELECT 'LOGGED: Повторное заполнение завершено.' AS status;

INSERT INTO test_unlogged (data, num_value)
SELECT
    'Unlogged Data ' || s::text,
    (s % 1000)
FROM generate_series(1, 100000) s;
SELECT 'UNLOGGED: Повторное заполнение завершено.' AS status;

-- 7. ЗАМЕРЫ НА УДАЛЕНИЕ ПО ОДНОЙ (SINGLE DELETE)

-- Кейс 7.1: Удаление по одной (Single Delete Simulation) - 10,000 транзакций
SELECT '--- 7.1. SINGLE DELETE (10,000 записей по одной) ---' AS test_info;

-- LOGGED: Удаление по одной
DO $$
BEGIN
    FOR i IN 1..10000 LOOP
        DELETE FROM test_logged WHERE id = i;
    END LOOP;
END $$;
SELECT 'LOGGED: Single Delete завершен.' AS status;

-- UNLOGGED: Удаление по одной
DO $$
BEGIN
    FOR i IN 1..10000 LOOP
        DELETE FROM test_unlogged WHERE id = i;
    END LOOP;
END $$;
SELECT 'UNLOGGED: Single Delete завершен.' AS status;

-- 8. ЗАВЕРШЕНИЕ
\timing off
SELECT '--- ТЕСТЫ ЗАВЕРШЕНЫ. Сравните результаты времени выполнения. ---' AS test_info;