-- Скрипт миграции данных из оригинальной таблицы users в партицированную

-- Проверяем количество записей в оригинальной таблице
SELECT COUNT(*) as original_count FROM users;

-- Копируем данные из оригинальной таблицы в партицированную
INSERT INTO users_partitioned 
SELECT user_id, password_hash, name, user_type 
FROM users;

-- Проверяем количество записей в партицированной таблице
SELECT COUNT(*) as partitioned_count FROM users_partitioned;

-- Проверяем распределение по партициям
SELECT 
    tableoid::regclass AS partition_name,
    COUNT(*) AS row_count
FROM users_partitioned
GROUP BY tableoid::regclass
ORDER BY partition_name;
