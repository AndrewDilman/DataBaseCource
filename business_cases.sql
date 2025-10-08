-- БИЗНЕС-КЕЙСЫ ДЛЯ МАРКЕТПЛЕЙСА

-- АГРЕГИРУЮЩИЕ ЗАПРОСЫ (3-5 запросов)

-- 1. Статистика по продавцам: количество товаров и средний рейтинг
SELECT 
    u.user_id,
    u.name as merchant_name,
    COUNT(g.good_id) as total_products,
    AVG(r.rating) as avg_rating,
    COUNT(r.id) as total_reviews
FROM users u
LEFT JOIN goods g ON u.user_id = g.merch_id
LEFT JOIN reviews r ON g.good_id = r.good_id
WHERE u.user_type = 'merchant'
GROUP BY u.user_id, u.name
ORDER BY total_products DESC, avg_rating DESC;

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

-- 3. Ежемесячная статистика заказов (если бы было поле даты)
-- Предположим, что у orders есть поле order_date TIMESTAMP
-- SELECT 
--     DATE_TRUNC('month', order_date) as month,
--     COUNT(*) as total_orders,
--     COUNT(DISTINCT user_id) as unique_customers,
--     SUM(total_amount) as total_revenue
-- FROM orders
-- GROUP BY DATE_TRUNC('month', order_date)
-- ORDER BY month;

-- 4. Статистика по покупателям: количество заказов и отзывов
SELECT 
    u.user_id,
    u.name as customer_name,
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT r.id) as total_reviews,
    AVG(r.rating) as avg_rating_given
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
LEFT JOIN reviews r ON u.user_id = r.user_id
WHERE u.user_type = 'customer'
GROUP BY u.user_id, u.name
ORDER BY total_orders DESC;

-- 5. Анализ популярности товаров
SELECT 
    g.good_id,
    g.name as product_name,
    COUNT(DISTINCT o.id) as times_ordered,
    COUNT(DISTINCT r.id) as total_reviews,
    AVG(r.rating) as avg_rating,
    u.name as merchant_name
FROM goods g
LEFT JOIN orders o ON g.good_id = o.good_id
LEFT JOIN reviews r ON g.good_id = r.good_id
LEFT JOIN users u ON g.merch_id = u.user_id
GROUP BY g.good_id, g.name, u.name
ORDER BY times_ordered DESC, avg_rating DESC;

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
GROUP BY u.user_id, u.name;

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
ORDER BY c.name, order_count DESC;

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
ORDER BY u.user_id, o.id;

-- 4. Скользящее среднее рейтинга для товаров
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
ORDER BY g.good_id, r.id;

-- 5. Процентное соотношение заказов по категориям
SELECT 
    c.caty_id,
    c.name as category_name,
    COUNT(o.id) as order_count,
    ROUND(
        COUNT(o.id) * 100.0 / SUM(COUNT(o.id)) OVER (), 
        2
    ) as percentage_of_total_orders
FROM categories c
LEFT JOIN goods g ON c.caty_id = g.caty_id
LEFT JOIN orders o ON g.good_id = o.good_id
GROUP BY c.caty_id, c.name
ORDER BY order_count DESC;

-- ЗАПРОСЫ С ОБЪЕДИНЕНИЕМ ТАБЛИЦ

-- 2 таблицы: Покупатели и их заказы
SELECT 
    u.user_id,
    u.name as customer_name,
    o.id as order_id,
    o.order_date
FROM users u
JOIN orders o ON u.user_id = o.user_id
WHERE u.user_type = 'customer'
ORDER BY u.name, o.order_date;

-- 2 таблицы: Товары и отзывы
SELECT 
    g.good_id,
    g.name as product_name,
    r.rating,
    r.comment,
    r.created_at as review_date
FROM goods g
JOIN reviews r ON g.good_id = r.good_id
ORDER BY g.name, r.rating DESC;

-- 3 таблицы: Заказы с информацией о покупателе и товаре
SELECT 
    o.id as order_id,
    u.name as customer_name,
    g.name as product_name,
    c.name as category_name,
    o.order_date
FROM orders o
JOIN users u ON o.user_id = u.user_id
JOIN goods g ON o.good_id = g.good_id
JOIN categories c ON g.caty_id = c.caty_id
ORDER BY o.order_date DESC;

-- 3 таблицы: Отзывы с полной информацией
SELECT 
    r.id as review_id,
    u_customer.name as customer_name,
    g.name as product_name,
    u_merchant.name as merchant_name,
    r.rating,
    r.comment
FROM reviews r
JOIN users u_customer ON r.user_id = u_customer.user_id
JOIN goods g ON r.good_id = g.good_id
JOIN users u_merchant ON g.merch_id = u_merchant.user_id
ORDER BY r.rating DESC;

-- 3 таблицы: Товары с категориями и продавцами
SELECT 
    g.good_id,
    g.name as product_name,
    c.name as category_name,
    u.name as merchant_name,
    COUNT(o.id) as total_orders
FROM goods g
JOIN categories c ON g.caty_id = c.caty_id
JOIN users u ON g.merch_id = u.user_id
LEFT JOIN orders o ON g.good_id = o.good_id
GROUP BY g.good_id, g.name, c.name, u.name
ORDER BY total_orders DESC;

-- 3 таблицы: История покупок с деталями
SELECT 
    ph.id as history_id,
    u.name as customer_name,
    o.id as order_id,
    g.name as product_name,
    ph.purchase_date
FROM purchase_history ph
JOIN users u ON ph.user_id = u.user_id
JOIN orders o ON ph.order_id = o.id
JOIN goods g ON o.good_id = g.good_id
ORDER BY ph.purchase_date DESC;

-- 4 таблицы: Полная информация о заказах
SELECT 
    o.id as order_id,
    u_customer.name as customer_name,
    g.name as product_name,
    u_merchant.name as merchant_name,
    c.name as category_name,
    o.order_date
FROM orders o
JOIN users u_customer ON o.user_id = u_customer.user_id
JOIN goods g ON o.good_id = g.good_id
JOIN users u_merchant ON g.merch_id = u_merchant.user_id
JOIN categories c ON g.caty_id = c.caty_id
ORDER BY o.order_date DESC
LIMIT 10;

-- 5 таблиц: Полная аналитика продаж
SELECT 
    o.id as order_id,
    u_customer.name as customer_name,
    g.name as product_name,
    u_merchant.name as merchant_name,
    c.name as category_name,
    r.rating,
    r.comment,
    o.order_date,
    a.name as shipping_address
FROM orders o
JOIN users u_customer ON o.user_id = u_customer.user_id
JOIN goods g ON o.good_id = g.good_id
JOIN users u_merchant ON g.merch_id = u_merchant.user_id
JOIN categories c ON g.caty_id = c.caty_id
LEFT JOIN reviews r ON (r.user_id = u_customer.user_id AND r.good_id = g.good_id)
LEFT JOIN addresses a ON (SELECT addr_id FROM pickup_points ORDER BY RANDOM() LIMIT 1) = a.addr_id
ORDER BY o.order_date DESC
LIMIT 10;