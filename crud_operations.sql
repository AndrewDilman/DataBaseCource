-- CRUD операции для таблицы users
-- CREATE
INSERT INTO users (password_hash, name, user_type) 
VALUES ('new_hash', 'Новый Пользователь', 'customer');

-- READ
SELECT * FROM users WHERE user_id = 1;
SELECT * FROM users WHERE user_type = 'merchant';

-- UPDATE
UPDATE users SET name = 'Обновленное Имя' WHERE user_id = 1;

-- DELETE
DELETE FROM users WHERE user_id = 1;

-- CRUD для categories
INSERT INTO categories (name) VALUES ('Новая Категория');
SELECT * FROM categories WHERE caty_id = 1;
UPDATE categories SET name = 'Обновленная Категория' WHERE caty_id = 1;
DELETE FROM categories WHERE caty_id = 1;

-- CRUD для addresses
INSERT INTO addresses (name) VALUES ('Новый Адрес');
SELECT * FROM addresses WHERE addr_id = 1;
UPDATE addresses SET name = 'Обновленный Адрес' WHERE addr_id = 1;
DELETE FROM addresses WHERE addr_id = 1;

-- CRUD для goods
INSERT INTO goods (merch_id, caty_id, name) VALUES (1, 1, 'Новый Товар');
SELECT * FROM goods WHERE good_id = 1;
UPDATE goods SET name = 'Обновленный Товар' WHERE good_id = 1;
DELETE FROM goods WHERE good_id = 1;

-- CRUD для orders
INSERT INTO orders (user_id, good_id) VALUES (1, 1);
SELECT * FROM orders WHERE id = 1;
UPDATE orders SET user_id = 2 WHERE id = 1;
DELETE FROM orders WHERE id = 1;

-- CRUD для reviews
INSERT INTO reviews (user_id, good_id, rating, comment) 
VALUES (1, 1, 5, 'Отличный товар!');
SELECT * FROM reviews WHERE id = 1;
UPDATE reviews SET rating = 4 WHERE id = 1;
DELETE FROM reviews WHERE id = 1;

-- CRUD для purchase_history
INSERT INTO purchase_history (user_id, order_id) VALUES (1, 1);
SELECT * FROM purchase_history WHERE id = 1;
UPDATE purchase_history SET user_id = 2 WHERE id = 1;
DELETE FROM purchase_history WHERE id = 1;

-- CRUD для pickup_points
INSERT INTO pickup_points (addr_id) VALUES (1);
SELECT * FROM pickup_points WHERE id = 1;
UPDATE pickup_points SET addr_id = 2 WHERE id = 1;
DELETE FROM pickup_points WHERE id = 1;

-- CRUD для warehouses
INSERT INTO warehouses (addr_id) VALUES (1);
SELECT * FROM warehouses WHERE id = 1;
UPDATE warehouses SET addr_id = 2 WHERE id = 1;
DELETE FROM warehouses WHERE id = 1;