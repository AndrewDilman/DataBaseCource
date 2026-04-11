# PostgreSQL - Операции с данными

## CRUD операции

### Создание данных (INSERT)

#### Добавление адреса

```sql
INSERT INTO addresses (name) 
VALUES ('ул. Пушкина, д. 1, Москва');
```

#### Добавление категории

```sql
INSERT INTO categories (name) 
VALUES ('Электроника');
```

#### Добавление пользователя

```sql
-- Продавец
INSERT INTO users (password_hash, name, user_type)
VALUES ('hashed_password', 'Магазин техники', 'merchant');

-- Покупатель
INSERT INTO users (password_hash, name, user_type)
VALUES ('hashed_password', 'Иван Иванов', 'customer');
```

#### Добавление товара

```sql
INSERT INTO goods (merch_id, caty_id, name)
VALUES (1, 1, 'Смартфон Samsung Galaxy S24');
```

#### Добавление заказа

```sql
INSERT INTO orders (user_id, good_id)
VALUES (6, 1);
```

#### Добавление отзыва

```sql
INSERT INTO reviews (user_id, good_id, rating, comment)
VALUES (6, 1, 5, 'Отличный товар! Рекомендую.');
```

### Чтение данных (SELECT)

#### Получить все категории

```sql
SELECT * FROM categories;
```

#### Получить товары с информацией о продавце и категории (через представление)

```sql
SELECT * FROM goods_view;
```

#### Получить товары определённого продавца

```sql
SELECT g.good_id, g.name, c.name as category
FROM goods g
JOIN categories c ON g.caty_id = c.caty_id
WHERE g.merch_id = 1;
```

#### Получить заказы пользователя

```sql
SELECT o.id, g.name as product_name, u.name as merchant
FROM orders o
JOIN goods g ON o.good_id = g.good_id
JOIN users u ON g.merch_id = u.user_id
WHERE o.user_id = 6;
```

#### Получить отзывы товара с именами пользователей

```sql
SELECT u.name, r.rating, r.comment
FROM reviews r
JOIN users u ON r.user_id = u.user_id
WHERE r.good_id = 1
ORDER BY r.rating DESC;
```

#### Получить средний рейтинг товара

```sql
SELECT 
    g.name,
    COUNT(r.id) as review_count,
    AVG(r.rating)::NUMERIC(10,2) as avg_rating
FROM goods g
LEFT JOIN reviews r ON g.good_id = r.good_id
WHERE g.good_id = 1
GROUP BY g.good_id, g.name;
```

#### Количество товаров по категориям

```sql
SELECT 
    c.name as category,
    COUNT(g.good_id) as product_count
FROM categories c
LEFT JOIN goods g ON c.caty_id = g.caty_id
GROUP BY c.caty_id, c.name
ORDER BY product_count DESC;
```

### Обновление данных (UPDATE)

#### Изменить название товара

```sql
UPDATE goods 
SET name = 'Смартфон Samsung Galaxy S24 Ultra'
WHERE good_id = 1;
```

#### Изменить отзыв

```sql
UPDATE reviews 
SET rating = 4, comment = 'Хороший товар, но дороговат'
WHERE user_id = 6 AND good_id = 1;
```

#### Обновить несколько полей

```sql
UPDATE goods 
SET 
    name = 'Новое название',
    caty_id = 2
WHERE good_id = 1;
```

### Удаление данных (DELETE)

#### Удалить отзыв

```sql
DELETE FROM reviews 
WHERE id = 1;
```

#### Удалить товар (с каскадным удалением заказов)

```sql
DELETE FROM goods 
WHERE good_id = 1;
```

#### Удалить все товары продавца

```sql
DELETE FROM goods 
WHERE merch_id = 1;
```

### Массовые операции

#### Вставка нескольких записей

```sql
INSERT INTO categories (name) VALUES
    ('Электроника'),
    ('Одежда'),
    ('Книги'),
    ('Дом и сад'),
    ('Спорт');
```

#### Обновление с JOIN

```sql
UPDATE goods g
SET name = g.name || ' (обновлено)'
FROM users u
WHERE g.merch_id = u.user_id AND u.user_type = 'merchant';
```

#### Удаление с JOIN

```sql
DELETE FROM orders
WHERE user_id IN (
    SELECT user_id 
    FROM users 
    WHERE user_type = 'customer'
);
```

## Агрегатные функции

### COUNT - подсчёт записей

```sql
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM goods WHERE merch_id = 1;
```

### SUM, AVG, MIN, MAX

```sql
SELECT 
    SUM(amount) as total,
    AVG(rating)::NUMERIC(10,2) as avg_rating,
    MIN(price) as min_price,
    MAX(price) as max_price
FROM goods;
```

### GROUP BY - группировка

```sql
SELECT 
    c.name as category,
    COUNT(g.good_id) as product_count
FROM categories c
LEFT JOIN goods g ON c.caty_id = g.caty_id
GROUP BY c.caty_id, c.name
HAVING COUNT(g.good_id) > 0
ORDER BY product_count DESC;
```

### Фильтрация с HAVING

```sql
SELECT 
    merch_id,
    COUNT(*) as product_count
FROM goods
GROUP BY merch_id
HAVING COUNT(*) >= 3;
```

## Транзакции

### Начать транзакцию и откатить

```sql
BEGIN;

INSERT INTO categories (name) VALUES ('Тестовая категория');

ROLLBACK;
```

### Начать транзакцию и зафиксировать

```sql
BEGIN;

INSERT INTO categories (name) VALUES ('Новая категория');
INSERT INTO goods (merch_id, caty_id, name) VALUES (1, lastval(), 'Товар');

COMMIT;
```

### Точка сохранения

```sql
BEGIN;

INSERT INTO users (password_hash, name, user_type) 
VALUES ('hash', 'Тест', 'customer');

SAVEPOINT sp1;

INSERT INTO goods (merch_id, caty_id, name) 
VALUES (1, 1, 'Товар 1');

ROLLBACK TO SAVEPOINT sp1;

COMMIT;
```

## Работа с представлениями

### Создание представления

```sql
CREATE OR REPLACE VIEW user_orders AS
SELECT 
    u.name as customer,
    g.name as product,
    o.id as order_id
FROM orders o
JOIN users u ON o.user_id = u.user_id
JOIN goods g ON o.good_id = g.good_id;
```

### Использование представления

```sql
SELECT * FROM user_orders WHERE customer = 'Иван Иванов';
```

## Работа с последовательностями

### Получить следующее значение

```sql
SELECT nextval('categories_caty_id_seq');
```

### Получить текущее значение

```sql
SELECT currval('categories_caty_id_seq');
```

## Полезные запросы

### Топ-5 популярных товаров

```sql
SELECT 
    g.name,
    COUNT(o.id) as order_count
FROM goods g
JOIN orders o ON g.good_id = o.good_id
GROUP BY g.good_id, g.name
ORDER BY order_count DESC
LIMIT 5;
```

### Пользователи с наибольшим количеством заказов

```sql
SELECT 
    u.name,
    COUNT(o.id) as order_count,
    SUM(g.price) as total_spent
FROM users u
JOIN orders o ON u.user_id = o.user_id
JOIN goods g ON o.good_id = g.good_id
GROUP BY u.user_id, u.name
ORDER BY order_count DESC
LIMIT 10;
```

### Товары без отзывов

```sql
SELECT g.good_id, g.name
FROM goods g
LEFT JOIN reviews r ON g.good_id = r.good_id
WHERE r.id IS NULL;
```

## Подключение

```bash
psql -h localhost -p 5433 -U admin -d marketplace
```

## Смотрите также

- [02_schema_in_project.md](02_schema_in_project.md) - Схема БД
- [04_replication.md](04_replication.md) - Логическая репликация
- [05_partitioning.md](05_partitioning.md) - Партиционирование