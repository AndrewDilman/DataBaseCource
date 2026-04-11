# PostgreSQL - Партиционирование

## Введение

Партиционирование (секционирование) разделяет одну большую таблицу на несколько меньших физических таблиц (партиций). Это улучшает производительность и управляемость больших таблиц.

## Типы партиционирования

### По диапазону (Range)

Таблица разделяется по диапазону значений (обычно даты или числа).

```sql
CREATE TABLE orders (
    id SERIAL,
    created_at TIMESTAMP NOT NULL,
    amount NUMERIC
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2024_q1 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE orders_2024_q2 PARTITION OF orders
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');
```

### По списку (List)

Таблица разделяется по конкретным значениям.

```sql
CREATE TABLE customers (
    region VARCHAR(2),
    id SERIAL
) PARTITION BY LIST (region);

CREATE TABLE customers_msk PARTITION OF customers
    FOR VALUES IN ('MS', 'MO');

CREATE TABLE customers_spb PARTITION OF customers
    FOR VALUES IN ('SP', 'LO');
```

### По хэшу (Hash)

Таблица разделяется по остатку от деления.

```sql
CREATE TABLE users (
    id SERIAL
) PARTITION BY HASH (id);

CREATE TABLE users_p0 PARTITION OF users
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);

CREATE TABLE users_p1 PARTITION OF users
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);
```

## Партиционирование в проекте

### Пример: users_partitioned

```sql
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
CREATE TABLE users_p1 PARTITION OF users_partitioned
    FOR VALUES FROM (1) TO (100001);      -- 1-100,000

CREATE TABLE users_p2 PARTITION OF users_partitioned
    FOR VALUES FROM (10001) TO (200001); -- 100,001-200,000

CREATE TABLE users_p3 PARTITION OF users_partitioned
    FOR VALUES FROM (200001) TO (300001); -- 200,001-300,000

CREATE TABLE users_p4 PARTITION OF users_partitioned
    FOR VALUES FROM (300001) TO (400001); -- 300,001-400,000

-- Создаем индексы
CREATE INDEX idx_users_partitioned_user_id ON users_partitioned (user_id);
CREATE INDEX idx_users_partitioned_user_type ON users_partitioned (user_type);
```

## Управление партициями

### Создание новой партиции

```sql
-- Для диапазона
CREATE TABLE users_p5 PARTITION OF users_partitioned
    FOR VALUES FROM (400001) TO (500001);
```

### Удаление партиции

```sql
-- Удалить партицию (и данные)
DROP TABLE users_p1;

-- Удалить только данные, оставить партицию
TRUNCATE TABLE users_p1;
```

### Переименование партиции

```sql
ALTER TABLE users_p1 RENAME TO users_p1_old;
```

### Перемещение данных между партициями

```sql
-- Переместить данные из партиции
INSERT INTO users_p2 SELECT * FROM users_p1 WHERE user_id >= 100001;
DELETE FROM users_p1 WHERE user_id >= 100001;
```

### Добавление партиции по умолчанию

```sql
CREATE TABLE users_default PARTITION OF users_partitioned
    DEFAULT;
```

### Проверка, что запрос использует партиции

```sql
EXPLAIN SELECT * FROM users_partitioned WHERE user_id BETWEEN 100 AND 200;
```

## Преимущества партиционирования

1. **Производительность** - запросы к одной партиции быстрее
2. **Индексы** - меньшие индексы, быстрее обновляются
3. **Управление** - можно архивировать старые партиции
4. **Параллелизм** - можно распределить партиции по дискам

## Недостатки

1. **Сложность** - требует планирования
2. **Ограничения** - не все операции поддерживают партиции
3. **Overhead** - небольшие накладные расходы

## Оптимизация запросов

### Использование partition pruning

PostgreSQL автоматически исключает ненужные партиции:

```sql
-- Только одна партиция
SELECT * FROM users_partitioned WHERE user_id = 150000;

-- Две партиции
SELECT * FROM users_partitioned WHERE user_id BETWEEN 100 AND 200000;
```

### Индексы на партициях

```sql
-- Индекс на конкретной партиции
CREATE INDEX idx_users_p1_type ON users_p1 (user_type);
```

## Миграция на партиционированную таблицу

### Шаг 1: Создать партиционированную таблицу

```sql
CREATE TABLE users_new (...) PARTITION BY RANGE (user_id);
-- создать партиции
```

### Шаг 2: Перенести данные

```sql
INSERT INTO users_new SELECT * FROM users_old;
```

### Шаг 3: Переименовать

```sql
ALTER TABLE users_old RENAME TO users_old_backup;
ALTER TABLE users_new RENAME TO users;
```

### Шаг 4: Создать представления и FK

```sql
-- Пересоздать индексы, представления, внешние ключи
```

## Мониторинг

### Размер партиций

```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Количество строк

```sql
SELECT 
    relname,
    n_live_tup
FROM pg_stat_user_tables
WHERE relname LIKE 'users_p%'
ORDER BY relname;
```

## Лучшие практики

1. **Размер партиции** - 10-50 миллионов строк
2. **Ключ партиционирования** - часто используемый в WHERE
3. **Индексы** - создавать на каждой партиции
4. **Default партиция** - на случай ошибок

## Подключение

```bash
psql -h localhost -p 5433 -U admin -d marketplace
```

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия
- [02_schema_in_project.md](02_schema_in_project.md) - Схема БД
- [03_operations.md](03_operations.md) - Операции