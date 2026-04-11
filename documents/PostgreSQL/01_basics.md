# PostgreSQL - Базовые понятия

## Введение

PostgreSQL - это объектно-реляционная система управления базами данных (ORDBMS) с открытым исходным кодом. Она известна своей надёжностью, расширяемостью и соответствием стандартам SQL.

## Основные понятия

### Таблицы (Tables)

Таблицы - это основные структуры хранения данных в PostgreSQL. Каждая таблица состоит из строк (записей) и столбцов (полей).

```sql
CREATE TABLE table_name (
    column1_name data_type constraints,
    column2_name data_type constraints,
    ...
);
```

### Типы данных PostgreSQL

| Категория | Типы | Описание |
|-----------|------|-----------|
| Числовые | INTEGER, BIGINT, SMALLINT, NUMERIC, DECIMAL, REAL, DOUBLE PRECISION | Целые и дробные числа |
| Строковые | VARCHAR(n), CHAR(n), TEXT | Текстовые данные |
| Дата/Время | DATE, TIME, TIMESTAMP, TIMESTAMPTZ, INTERVAL | Даты и время |
| Логические | BOOLEAN | Истина/Ложь |
| UUID | UUID | Универсальные уникальные идентификаторы |
| JSON | JSON, JSONB | JSON документы |
| Массивы | ARRAY | Массивы любого типа |

### Ограничения (Constraints)

Ограничения обеспечивают целостность данных:

- **PRIMARY KEY** - уникальный идентификатор строки
- **FOREIGN KEY** - ссылка на строку в другой таблице
- **NOT NULL** - поле не может быть пустым
- **UNIQUE** - уникальное значение в столбце
- **CHECK** - условие, которому должно удовлетворять значение
- **DEFAULT** - значение по умолчанию

### Индексы (Indexes)

Индексы ускоряют поиск данных. Создаются на одном или нескольких столбцах.

```sql
CREATE INDEX idx_name ON table_name (column1, column2);
```

Виды индексов:
- **B-tree** (по умолчанию) - для равенства и диапазонов
- **Hash** - для точного равенства
- **GiST** - для геометрических данных
- **GIN** - для полнотекстового поиска и массивов
- **BRIN** - для больших таблиц с естественным порядком

### Представления (Views)

Представления - это сохранённые запросы, которые можно использовать как таблицы:

```sql
CREATE VIEW view_name AS
SELECT column1, column2
FROM table_name
WHERE condition;
```

### Схемы (Schemas)

Схемы - это пространства имён внутри базы данных:

```sql
CREATE SCHEMA schema_name;
```

По умолчанию все таблицы создаются в схеме `public`.

## Логическая репликация

Логическая репликация в PostgreSQL позволяет реплицировать данные на уровне таблиц или всей базы данных.

### Публикации (Publications)

Публикация определяет, какие таблицы репли��ируются:

```sql
CREATE PUBLICATION publication_name FOR TABLE table1, table2;
```

### Подписки (Subscriptions)

Подписка соединяет本地-BD с удалённой публикацией:

```sql
CREATE SUBSCRIPTION subscription_name
CONNECTION 'host=remotehost port=5432 dbname=mydb user=admin password=pass'
PUBLICATION publication_name;
```

## Партиционирование (Partitioning)

Партиционирование разделяет большую таблицу на меньшие (партиции) по диапазонам, спискам или хэшу.

### Партиционирование по диапазону (Range)

```sql
CREATE TABLE orders (
    id SERIAL,
    created_at DATE NOT NULL,
    amount NUMERIC
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2024 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
```

### Партиционирование по списку (List)

```sql
CREATE TABLE customers (
    region VARCHAR(2),
    id SERIAL
) PARTITION BY LIST (region);

CREATE TABLE customers_moscow PARTITION OF customers
    FOR VALUES IN ('MS', 'MO');
```

### Партиционирование по хэшу (Hash)

```sql
CREATE TABLE users (
    id SERIAL
) PARTITION BY HASH (id);

CREATE TABLE users_0 PARTITION OF users
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);
```

## Расширения (Extensions)

Расширения добавляют функциональность:

```sql
CREATE EXTENSION extension_name;
```

Полезные расширения:
- **pg_stat_statements** - статистика выполнения запросов
- **uuid-ossp** - генерация UUID
- **postgis** - географические данные
- **pg_trgm** - триграммный поиск

## Транзакции и ACID

ACID - четыре ключевых свойства транзакций:

- **Atomicity** (атомарность) - все операции выполняются или все откатываются
- **Consistency** (согласованность) - БД переходит из одного согласованного состояния в другое
- **Isolation** (изоляция) - параллельные транзакции не влияют друг на друга
- **Durability** (долговечность) - commit сохраняется даже при сбое системы

## Уровни изоляции

| Уровень | Описание | Грязное чтение | Неповторяемое чтение | Фантомы |
|---------|---------|----------------|-------------------|------------------|---------|
| READ UNCOMMITTED | Чтение незафиксированных данных | Возможно | Возможно | Возможно |
| READ COMMITTED | Чтение только фиксированных данных | Нет | Возможно | Возможно |
| REPEATABLE READ | Повторное чтение даёт тот же результат | Нет | Нет | Возможно |
| SERIALIZABLE | Полная изоляция | Нет | Нет | Нет |

## Подключение к PostgreSQL

### Через psql

```bash
psql -h localhost -p 5432 -U admin -d marketplace
```

### Параметры подключения

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| -h | Хост | localhost |
| -p | Порт | 5432 |
| -U | Пользователь | текущий пользователь ОС |
| -d | База данных | имя пользователя |
| -W | Запросить пароль | - |

## Основные команды psql

```sql
-- Список баз данных
\l

-- Подключи��ься к БД
\c database_name

-- Список таблиц
\dt

-- Список схем
\dn

-- Информация о таблице
\d table_name

-- Выполнить SQL файл
\i filename.sql

-- Выход
\q
```

## Смотрите также

- [02_schema_in_project.md](02_schema_in_project.md) - Схема БД в проекте
- [03_operations.md](03_operations.md) - Операции с данными
- [04_replication.md](04_replication.md) - Репликация
- [05_partitioning.md](05_partitioning.md) - Партиционирование
- [06_backup.md](06_backup.md) - Резервное копирование