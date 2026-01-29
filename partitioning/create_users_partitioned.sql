-- Скрипт создания партицированной версии таблицы users

-- Удаляем таблицу, если она уже существует
DROP TABLE IF EXISTS users_partitioned CASCADE;

-- Создаем партицированную таблицу users по диапазону user_id
CREATE TABLE users_partitioned (
    user_id INTEGER NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('customer', 'merchant'))
) PARTITION BY RANGE (user_id);

-- Создаем партиции по 100,000 записей
-- Диапазоны должны быть последовательными без пропусков и пересечений
CREATE TABLE users_p1 PARTITION OF users_partitioned
    FOR VALUES FROM (1) TO (100001);      -- 1-100,000

CREATE TABLE users_p2 PARTITION OF users_partitioned
    FOR VALUES FROM (100001) TO (200001); -- 100,001-200,000

CREATE TABLE users_p3 PARTITION OF users_partitioned
    FOR VALUES FROM (200001) TO (300001); -- 200,001-300,000

CREATE TABLE users_p4 PARTITION OF users_partitioned
    FOR VALUES FROM (300001) TO (40001); -- 300,001-400,000

CREATE TABLE users_p5 PARTITION OF users_partitioned
    FOR VALUES FROM (400001) TO (500001); -- 400,001-500,000

CREATE TABLE users_p6 PARTITION OF users_partitioned
    FOR VALUES FROM (500001) TO (60001); -- 500,001-600,000

CREATE TABLE users_p7 PARTITION OF users_partitioned
    FOR VALUES FROM (600001) TO (700001); -- 600,001-700,000

CREATE TABLE users_p8 PARTITION OF users_partitioned
    FOR VALUES FROM (700001) TO (800001); -- 700,001-800,000

CREATE TABLE users_p9 PARTITION OF users_partitioned
    FOR VALUES FROM (800001) TO (900001); -- 800,001-900,000

CREATE TABLE users_p10 PARTITION OF users_partitioned
    FOR VALUES FROM (900001) TO (1000001); -- 900,001-1,000

-- Создаем индекс на user_id для каждой партиции
CREATE INDEX idx_users_partitioned_user_id ON users_partitioned (user_id);

-- Создаем индекс на user_type для эффективности фильтрации по типу пользователя
CREATE INDEX idx_users_partitioned_user_type ON users_partitioned (user_type);
