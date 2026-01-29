-- БИЗНЕС-КЕЙСЫ ДЛЯ МАРКЕТПЛЕЙСА (ИСПРАВЛЕННАЯ ВЕРСИЯ)

-- АГРЕГИРУЮЩИЕ ЗАПРОСЫ (3-5 запросов)

-- 1. Статистика по продавцам: количество товаров и средний рейтинг
SELECT 
    u.user_id,
    u.name as merchant_name,
    COUNT(DISTINCT g.good_id) as total_products,
    ROUND(AVG(r.rating)::numeric, 2) as avg_rating,
    COUNT(DISTINCT r.id) as total_reviews
FROM users u
LEFT JOIN goods g ON u.user_id = g.merch_id
LEFT JOIN reviews r ON g.good_id = r.good_id
WHERE u.user_type = 'merchant'
GROUP BY u.user_id, u.name
HAVING COUNT(DISTINCT g.good_id) > 0
ORDER BY total_products DESC, avg_rating DESC
LIMIT 10;

-- 2. Статистика по категориям: количество товаров и заказов
SELECT 
    c.caty_id,
    c.name as category_name,
    COUNT(DISTINCT g.good_id) as total_products,
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT r.id) as total_reviews
FROM categories c
LEFT JOIN goods g ON c.caty_id = g.caty_id
LEFT JOIN orders o ON g.good_id = o.good_id
LEFT JOIN reviews r ON g.good_id = r.good_id
GROUP BY c.caty_id, c.name
ORDER BY total_orders DESC;

-- 3. Статистика по покупателям: количество заказов и отзывов
SELECT 
    u.user_id,
    u.name as customer_name,
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT r.id) as total_reviews,
    ROUND(AVG(r.rating)::numeric, 2) as avg_rating_given
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
LEFT JOIN reviews r ON u.user_id = r.user_id
WHERE u.user_type = 'customer'
GROUP BY u.user_id, u.name
HAVING COUNT(DISTINCT o.id) > 0
ORDER BY total_orders DESC
LIMIT 10;

-- 4. Анализ популярности товаров
SELECT 
    g.good_id,
    g.name as product_name,
    COUNT(DISTINCT o.id) as times_ordered,
    COUNT(DISTINCT r.id) as total_reviews,
    ROUND(AVG(r.rating)::numeric, 2) as avg_rating,
    u.name as merchant_name
FROM goods g
LEFT JOIN orders o ON g.good_id = o.good_id
LEFT JOIN reviews r ON g.good_id = r.good_id
LEFT JOIN users u ON g.merch_id = u.user_id
GROUP BY g.good_id, g.name, u.name
HAVING COUNT(DISTINCT o.id) > 0
ORDER BY times_ordered DESC, avg_rating DESC
LIMIT 10;

-- 5. Топ покупателей по активности
SELECT 
    u.user_id,
    u.name as customer_name,
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT r.id) as total_reviews,
    COUNT(DISTINCT g.good_id) as unique_products_bought
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
LEFT JOIN reviews r ON u.user_id = r.user_id
LEFT JOIN goods g ON o.good_id = g.good_id
WHERE u.user_type = 'customer'
GROUP BY u.user_id, u.name
HAVING COUNT(DISTINCT o.id) > 0
ORDER BY total_orders DESC
LIMIT 10;

-- ОКОННЫЕ ФУНКЦИИ (3-5 запросов)

-- 1. Рейтинг продавцов по количеству товаров
SELECT 
    u.user_id,
    u.name as merchant_name,
    COUNT(g.good_id) as product_count,
    RANK() OVER (ORDER BY COUNT(g.good_id) DESC) as rank_by_products,
    DENSE_RANK() OVER (ORDER BY COUNT(g.good_id) DESC) as dense_rank_products
FROM users u
LEFT JOIN goods g ON u.user_id = g.merch_id
WHERE u.user_type = 'merchant'
GROUP BY u.user_id, u.name
ORDER BY product_count DESC
LIMIT 10;

-- 2. Рейтинг товаров по количеству заказов в каждой категории
SELECT 
    g.good_id,
    g.name as product_name,
    c.name as category_name,
    COUNT(o.id) as order_count,
    RANK() OVER (PARTITION BY c.caty_id ORDER BY COUNT(o.id) DESC) as rank_in_category
FROM goods g
JOIN categories c ON g.caty_id = c.caty_id
LEFT JOIN orders o ON g.good_id = o.good_id
GROUP BY g.good_id, g.name, c.name, c.caty_id
HAVING COUNT(o.id) > 0
ORDER BY c.name, order_count DESC
LIMIT 20;

-- 3. Накопительная статистика заказов по покупателям
SELECT 
    u.user_id,
    u.name as customer_name,
    o.id as order_id,
    COUNT(o.id) OVER (PARTITION BY u.user_id) as total_orders_per_customer,
    ROW_NUMBER() OVER (PARTITION BY u.user_id ORDER BY o.id) as order_sequence
FROM users u
JOIN orders o ON u.user_id = o.user_id
WHERE u.user_type = 'customer'
ORDER BY u.user_id, o.id
LIMIT 20;

-- 4. Скользящее среднее рейтинга для товаров (по трем последним отзывам)
SELECT 
    g.good_id,
    g.name as product_name,
    r.rating,
    AVG(r.rating) OVER (
        PARTITION BY g.good_id 
        ORDER BY r.id 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) as moving_avg_rating
FROM goods g
JOIN reviews r ON g.good_id = r.good_id
ORDER BY g.good_id, r.id
LIMIT 20;

-- 5. Процентное соотношение заказов по категориям
SELECT 
    c.caty_id,
    c.name as category_name,
    COUNT(o.id) as order_count,
    ROUND(
        COUNT(o.id) * 100.0 / NULLIF(SUM(COUNT(o.id)) OVER (), 0), 
        2
    ) as percentage_of_total_orders
FROM categories c
LEFT JOIN goods g ON c.caty_id = g.caty_id
LEFT JOIN orders o ON g.good_id = o.good_id
GROUP BY c.caty_id, c.name
ORDER BY order_count DESC;

-- ЗАПРОСЫ С ОБЪЕДИНЕНИЕМ ТАБЛИЦ

-- Требуемые 8 запросов: 
--   - 2 запроса через объединение 2 таблиц
--   - 4 запроса через объединение 3 таблиц
--   - 1 запрос через объединение 4 таблиц
--   - 1 запрос через объединение 5 таблиц

-- [1/8] 2 таблицы: Покупатели и их заказы
SELECT 
    u.user_id,
    u.name AS customer_name,
    o.id AS order_id
FROM users u
JOIN orders o ON u.user_id = o.user_id
WHERE u.user_type = 'customer'
ORDER BY u.name, o.id
LIMIT 10;

-- [2/8] 2 таблицы: Товары и отзывы
SELECT 
    g.good_id,
    g.name AS product_name,
    r.rating,
    r.comment
FROM goods g
JOIN reviews r ON g.good_id = r.good_id
ORDER BY g.name, r.rating DESC
LIMIT 10;

-- [3/8] 3 таблицы: Заказы с покупателем и товаром
SELECT 
    o.id AS order_id,
    u.name AS customer_name,
    g.name AS product_name
FROM orders o
JOIN users u ON o.user_id = u.user_id
JOIN goods g ON o.good_id = g.good_id
ORDER BY o.id
LIMIT 10;

-- [4/8] 3 таблицы: Отзывы с покупателем и товаром
SELECT 
    r.id AS review_id,
    u.name AS customer_name,
    g.name AS product_name,
    r.rating
FROM reviews r
JOIN users u ON r.user_id = u.user_id
JOIN goods g ON r.good_id = g.good_id
ORDER BY r.rating DESC, r.id
LIMIT 10;

-- [5/8] 3 таблицы: Товары с продавцом и категорией
SELECT 
    g.good_id,
    g.name AS product_name,
    u.name AS merchant_name,
    c.name AS category_name
FROM goods g
JOIN users u ON g.merch_id = u.user_id
JOIN categories c ON g.caty_id = c.caty_id
ORDER BY category_name, product_name
LIMIT 10;

-- [6/8] 3 таблицы: Заказы с товаром и категорией
SELECT 
    o.id AS order_id,
    g.name AS product_name,
    c.name AS category_name
FROM orders o
JOIN goods g ON o.good_id = g.good_id
JOIN categories c ON g.caty_id = c.caty_id
ORDER BY o.id
LIMIT 10;

-- [7/8] 4 таблицы: Полная информация о заказах (покупатель, товар, продавец)
SELECT 
    o.id AS order_id,
    u_c.name AS customer_name,
    g.name AS product_name,
    u_m.name AS merchant_name
FROM orders o
JOIN users u_c ON o.user_id = u_c.user_id
JOIN goods g ON o.good_id = g.good_id
JOIN users u_m ON g.merch_id = u_m.user_id
ORDER BY o.id
LIMIT 10;

-- [8/8] 5 таблиц: Отзывы с покупателем, товаром, продавцом и категорией
SELECT 
    r.id AS review_id,
    u_c.name AS customer_name,
    g.name AS product_name,
    u_m.name AS merchant_name,
    c.name AS category_name,
    r.rating,
    r.comment
FROM reviews r
JOIN users u_c ON r.user_id = u_c.user_id
JOIN goods g ON r.good_id = g.good_id
JOIN users u_m ON g.merch_id = u_m.user_id
JOIN categories c ON g.caty_id = c.caty_id
ORDER BY r.rating DESC, r.id
LIMIT 10;