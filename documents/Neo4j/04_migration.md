# Neo4j - Миграция из PostgreSQL

## Введение

Миграция данных из PostgreSQL в Neo4j выполняется через экспорт данных в CSV файлы и загрузку через Cypher LOAD CSV.

## Процесс миграции

### Шаг 1: Экспорт из PostgreSQL

Экспорт таблиц в CSV формат:

```bash
# Экспорт пользователей (покупатели)
docker exec marketplace-db psql -U admin -d marketplace -c "
    COPY (SELECT user_id, name, user_type FROM users WHERE user_type = 'customer') 
    TO '/tmp/neo4j_export/customers.csv' WITH CSV HEADER;
"

# Экспорт пользователей (продавцы)
docker exec marketplace-db psql -U admin -d marketplace -c "
    COPY (SELECT user_id, name, user_type FROM users WHERE user_type = 'merchant') 
    TO '/tmp/neo4j_export/merchants.csv' WITH CSV HEADER;
"

# Экспорт категорий
docker exec marketplace-db psql -U admin -d marketplace -c "
    COPY (SELECT caty_id, name FROM categories) 
    TO '/tmp/neo4j_export/categories.csv' WITH CSV HEADER;
"

# Экспорт товаров
docker exec marketplace-db psql -U admin -d marketplace -c "
    COPY (SELECT good_id, name, merch_id, caty_id FROM goods) 
    TO '/tmp/neo4j_export/goods.csv' WITH CSV HEADER;
"

# Экспорт заказов
docker exec marketplace-db psql -U admin -d marketplace -c "
    COPY (SELECT user_id, good_id, COUNT(*) as cnt FROM orders GROUP BY user_id, good_id) 
    TO '/tmp/neo4j_export/orders.csv' WITH CSV HEADER;
"

# Экспорт отзывов
docker exec marketplace-db psql -U admin -d marketplace -c "
    COPY (SELECT user_id, good_id, rating, comment FROM reviews) 
    TO '/tmp/neo4j_export/reviews.csv' WITH CSV HEADER;
"
```

### Шаг 2: Копирование в Neo4j

```bash
# Копирование файлов
docker cp marketplace-db:/tmp/neo4j_export/. /tmp/neo4j_import/
docker cp /tmp/neo4j_import/. marketplace-neo4j:/var/lib/neo4j/import/
```

### Шаг 3: Создание ограничений

```cypher
CREATE CONSTRAINT FOR (u:User) REQUIRE u.userId IS UNIQUE;
CREATE CONSTRAINT FOR (p:Product) REQUIRE p.productId IS UNIQUE;
CREATE CONSTRAINT FOR (c:Category) REQUIRE c.categoryId IS UNIQUE;
```

### Шаг 4: Загрузка узлов

#### Пользователи

```cypher
LOAD CSV WITH HEADERS FROM 'file:///customers.csv' AS row
CALL {
    WITH row
    MERGE (u:User {userId: toInteger(row.user_id)})
    SET u.name = row.name, u.type = row.user_type
} IN TRANSACTIONS OF 5000 ROWS;

LOAD CSV WITH HEADERS FROM 'file:///merchants.csv' AS row
CALL {
    WITH row
    MERGE (u:User {userId: toInteger(row.user_id)})
    SET u.name = row.name, u.type = row.user_type
} IN TRANSACTIONS OF 5000 ROWS;
```

#### Категории

```cypher
LOAD CSV WITH HEADERS FROM 'file:///categories.csv' AS row
CALL {
    WITH row
    MERGE (c:Category {categoryId: toInteger(row.caty_id)})
    SET c.name = row.name
} IN TRANSACTIONS OF 1000 ROWS;
```

#### Товары

```cypher
LOAD CSV WITH HEADERS FROM 'file:///goods.csv' AS row
CALL {
    WITH row
    MERGE (p:Product {productId: toInteger(row.good_id)})
    SET p.name = row.name,
        p.merchantId = toInteger(row.merch_id),
        p.categoryId = toInteger(row.caty_id)
} IN TRANSACTIONS OF 5000 ROWS;
```

### Шаг 5: Загрузка связей

#### SOLD_BY

```cypher
LOAD CSV WITH HEADERS FROM 'file:///goods.csv' AS row
CALL {
    WITH row
    MATCH (p:Product {productId: toInteger(row.good_id)})
    MATCH (u:User {userId: toInteger(row.merch_id)})
    MERGE (p)-[:SOLD_BY]->(u)
} IN TRANSACTIONS OF 5000 ROWS;
```

#### IN_CATEGORY

```cypher
LOAD CSV WITH HEADERS FROM 'file:///goods.csv' AS row
CALL {
    WITH row
    MATCH (p:Product {productId: toInteger(row.good_id)})
    MATCH (c:Category {categoryId: toInteger(row.caty_id)})
    MERGE (p)-[:IN_CATEGORY]->(c)
} IN TRANSACTIONS OF 5000 ROWS;
```

#### BOUGHT

```cypher
LOAD CSV WITH HEADERS FROM 'file:///orders.csv' AS row
CALL {
    WITH row
    MATCH (u:User {userId: toInteger(row.user_id)})
    MATCH (p:Product {productId: toInteger(row.good_id)})
    MERGE (u)-[b:BOUGHT]->(p)
    SET b.count = toInteger(row.cnt)
} IN TRANSACTIONS OF 5000 ROWS;
```

#### REVIEWED

```cypher
LOAD CSV WITH HEADERS FROM 'file:///reviews.csv' AS row
CALL {
    WITH row
    MATCH (u:User {userId: toInteger(row.user_id)})
    MATCH (p:Product {productId: toInteger(row.good_id)})
    MERGE (u)-[r:REVIEWED]->(p)
    SET r.rating = toInteger(row.rating),
        r.comment = row.comment
} IN TRANSACTIONS OF 5000 ROWS;
```

## Скрипт миграции

Полный скрипт миграции: [neo4j/migrate.sh](../../neo4j/migrate.sh)

### Запуск

```bash
./neo4j/migrate.sh
```

### Проверка

```cypher
MATCH (u:User) RETURN count(u)
MATCH (p:Product) RETURN count(p)
MATCH (c:Category) RETURN count(c)
```

## Оптимизация

### IN TRANSACTIONS

Использование `IN TRANSACTIONS`减少 памяти:

```cypher
// Вместо одного большого запроса
LOAD CSV WITH HEADERS FROM 'file:///file.csv' AS row
MERGE (n:Node {id: toInteger(row.id)})
SET n.name = row.name

// Разбить на транзакции
LOAD CSV WITH HEADERS FROM 'file:///file.csv' AS row
CALL {
    WITH row
    MERGE (n:Node {id: toInteger(row.id)})
    SET n.name = row.name
} IN TRANSACTIONS OF 5000 ROWS
```

### Параметры памяти

Увеличить heap size если нужно:

```bash
docker exec marketplace-neo4j neo4j stop
docker exec marketplace-neo4j neo4j-admin memory ...

# Или через docker-compose
neo4j:
    environment:
        NEO4J_dbms_memory_heap_max__size: 2G
```

## Устранение проблем

### Файл не найден

Убедитесь что файл скопирован:

```bash
docker exec marketplace-neo4j ls -la /var/lib/neo4j/import/
```

### Memory error

Увеличить heap:

```bash
NEO4J_dbms_memory_heap_max__size: 4G
```

### Duplicate keys

Удалить дубликаты:

```cypher
MATCH (n)
WITH n.userId as id, n, count(*) as cnt
WHERE cnt > 1
DETACH DELETE n
```

## Подключение

```bash
docker exec marketplace-neo4j cypher-shell -u neo4j -p 12345678
```

## Быстрый запуск для тестирования

Для тестирования PostgreSQL и Neo4j без других сервисов (MongoDB, Redis, Kafka и т.д.):

### Шаг 1: Запуск только PostgreSQL и Neo4j

```bash
# Запустить только нужные сервисы
docker-compose up -d postgres neo4j
```

### Шаг 2: Проверка статуса

```bash
docker ps
```

Должны быть видны:
- `marketplace-db` (PostgreSQL, порт 5433)
- `marketplace-neo4j` (Neo4j, порты 7474, 7687)

### Шаг 3: Генерация данных

```bash
# Скопировать скрипт в контейнер
docker cp small_rich_data.sql marketplace-db:/small_rich_data.sql

# Выполнить генерацию
docker exec -i marketplace-db psql -U admin -d marketplace -f /small_rich_data.sql
```

Ожидаемые данные:
- 30 продавцов
- 400 покупателей
- ~500 товаров
- 0-7 заказов на покупателя
- 30% отзывов

### Шаг 4: Миграция в Neo4j

```bash
bash neo4j/migrate.sh
```

### Шаг 5: Проверка данных

```bash
# Статистика PostgreSQL
docker exec -i marketplace-db psql -U admin -d marketplace -c "
SELECT 'Продавцы' as t, COUNT(*) FROM users WHERE user_type='merchant' 
UNION ALL SELECT 'Покупатели', COUNT(*) FROM users WHERE user_type='customer' 
UNION ALL SELECT 'Товары', COUNT(*) FROM goods 
UNION ALL SELECT 'Заказы', COUNT(*) FROM orders 
UNION ALL SELECT 'Отзывы', COUNT(*) FROM reviews;
"

# Статистика Neo4j
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 -c "
MATCH (u:User) RETURN 'Users', count(*) 
UNION ALL MATCH (p:Product) RETURN 'Products', count(*) 
UNION ALL MATCH (c:Category) RETURN 'Categories', count(*) 
UNION ALL MATCH ()-[r:SOLD_BY]->() RETURN 'SOLD_BY', count(*) 
UNION ALL MATCH ()-[r:IN_CATEGORY]->() RETURN 'IN_CATEGORY', count(*) 
UNION ALL MATCH ()-[r:BOUGHT]->() RETURN 'BOUGHT', count(*) 
UNION ALL MATCH ()-[r:REVIEWED]->() RETURN 'REVIEWED', count(*);
"
```

### Шаг 6: Подключение к Neo4j

Через браузер: http://localhost:7474
- Логин: `neo4j`
- Пароль: `12345678`

Через CLI:
```bash
docker exec -it marketplace-neo4j cypher-shell -u neo4j -p 12345678
```

### Шаг 7: Остановка

```bash
docker-compose down
```

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия
- [02_graph_model.md](02_graph_model.md) - Модель графа
- [03_queries.md](03_queries.md) - Запросы