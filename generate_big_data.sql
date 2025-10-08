-- ГЕНЕРАЦИЯ БОЛЬШОГО КОЛИЧЕСТВА ДАННЫХ (ИСПРАВЛЕННАЯ ВЕРСИЯ)

-- Очистка существующих данных
TRUNCATE TABLE purchase_history, reviews, orders, goods, users, categories, addresses, pickup_points, warehouses CASCADE;

-- 1. Генерация адресов (10,000 записей)
INSERT INTO addresses (name)
SELECT 
    'г. ' || 
    CASE (seq % 50) + 1
        WHEN 1 THEN 'Москва'
        WHEN 2 THEN 'Санкт-Петербург'
        WHEN 3 THEN 'Новосибирск'
        WHEN 4 THEN 'Екатеринбург'
        WHEN 5 THEN 'Казань'
        ELSE 'Город_' || ((seq % 50) + 1)
    END || 
    ', ул. ' || 
    CASE (seq % 20) + 1
        WHEN 1 THEN 'Ленина'
        WHEN 2 THEN 'Пушкина'
        WHEN 3 THEN 'Гагарина'
        WHEN 4 THEN 'Мира'
        WHEN 5 THEN 'Садовая'
        ELSE 'Улица_' || ((seq % 20) + 1)
    END || 
    ', д. ' || (seq % 100 + 1)
FROM generate_series(1, 10000) as seq;

-- 2. Генерация категорий (50 записей)
INSERT INTO categories (name)
SELECT 'Категория_' || seq FROM generate_series(1, 50) as seq;

-- 3. Генерация пользователей (100,000 записей)
INSERT INTO users (password_hash, name, user_type)
SELECT 
    md5(random()::text) as password_hash,
    CASE 
        WHEN seq <= 5000 THEN 'Продавец_' || seq
        ELSE 'Покупатель_' || (seq - 5000)
    END as name,
    CASE 
        WHEN seq <= 5000 THEN 'merchant'
        ELSE 'customer'
    END as user_type
FROM generate_series(1, 100000) as seq;

-- 4. Генерация товаров (500,000 записей) - ИСПРАВЛЕНО
INSERT INTO goods (merch_id, caty_id, name)
SELECT 
    -- Только существующие merchant users (1-5000)
    (random() * 4999 + 1)::int as merch_id,
    -- Только существующие категории (1-50)
    (random() * 49 + 1)::int as caty_id,
    'Товар_' || seq || '_категории_' || ((random() * 49 + 1)::int)
FROM generate_series(1, 500000) as seq;

-- 5. Генерация заказов (3,000,000 записей) - ИСПРАВЛЕНО
INSERT INTO orders (user_id, good_id)
SELECT 
    -- Только customer users (5001-100000)
    ((random() * 94999)::int + 5001) as user_id,
    -- Только существующие товары (1-500000)
    ((random() * 499999)::int + 1) as good_id
FROM generate_series(1, 3000000) as seq;

-- 6. Генерация отзывов (1,000,000 записей) - ПОЛНОСТЬЮ ПЕРЕПИСАННЫЙ БЛОК
INSERT INTO reviews (user_id, good_id, rating, comment)
SELECT 
    u.user_id,
    g.good_id,
    (random() * 4 + 1)::int as rating,
    CASE (random() * 5)::int
        WHEN 0 THEN 'Отличный товар!'
        WHEN 1 THEN 'Очень доволен покупкой'
        WHEN 2 THEN 'Нормального качества'
        WHEN 3 THEN 'Есть небольшие недостатки'
        WHEN 4 THEN 'Не рекомендую'
        ELSE 'Среднего качества'
    END as comment
FROM 
    (SELECT user_id FROM users WHERE user_type = 'customer' ORDER BY random() LIMIT 1000000) u
CROSS JOIN LATERAL
    (SELECT good_id FROM goods ORDER BY random() LIMIT 1) g
LIMIT 1000000;

-- 7. Генерация истории покупок (3,000,000 записей) - ИСПРАВЛЕНО
INSERT INTO purchase_history (user_id, order_id)
SELECT 
    o.user_id,
    o.id as order_id
FROM orders o;

-- 8. Генерация пунктов выдачи (1,000 записей)
INSERT INTO pickup_points (addr_id)
SELECT addr_id FROM addresses WHERE addr_id <= 1000;

-- 9. Генерация складов (500 записей)
INSERT INTO warehouses (addr_id)
SELECT addr_id FROM addresses WHERE addr_id BETWEEN 1001 AND 1500;

-- ПРОВЕРКА СГЕНЕРИРОВАННЫХ ДАННЫХ
SELECT 
    'Адреса' as table_name,
    COUNT(*) as record_count
FROM addresses
UNION ALL
SELECT 'Категории', COUNT(*) FROM categories
UNION ALL
SELECT 'Пользователи', COUNT(*) FROM users
UNION ALL
SELECT 'Товары', COUNT(*) FROM goods
UNION ALL
SELECT 'Заказы', COUNT(*) FROM orders
UNION ALL
SELECT 'Отзывы', COUNT(*) FROM reviews
UNION ALL
SELECT 'История покупок', COUNT(*) FROM purchase_history
UNION ALL
SELECT 'Пункты выдачи', COUNT(*) FROM pickup_points
UNION ALL
SELECT 'Склады', COUNT(*) FROM warehouses
ORDER BY record_count DESC;

-- ПРОВЕРКА СВЯЗЕЙ И ЦЕЛОСТНОСТИ ДАННЫХ
SELECT 'Проверка целостности данных:' as check_type;

-- Проверка, что нет "битых" связей
SELECT 'Товары без продавца: ' || COUNT(*)::text as issue
FROM goods g 
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = g.merch_id AND u.user_type = 'merchant')

UNION ALL
SELECT 'Заказы без покупателя: ' || COUNT(*) 
FROM orders o 
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = o.user_id AND u.user_type = 'customer')

UNION ALL
SELECT 'Заказы без товара: ' || COUNT(*) 
FROM orders o 
WHERE NOT EXISTS (SELECT 1 FROM goods g WHERE g.good_id = o.good_id)

UNION ALL
SELECT 'Отзывы без пользователя: ' || COUNT(*) 
FROM reviews r 
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = r.user_id)

UNION ALL
SELECT 'Отзывы без товара: ' || COUNT(*) 
FROM reviews r 
WHERE NOT EXISTS (SELECT 1 FROM goods g WHERE g.good_id = r.good_id);

-- ДОПОЛНИТЕЛЬНЫЕ ПРОВЕРКИ КАЧЕСТВА ДАННЫХ
SELECT 'Дополнительные проверки:' as check_type;

SELECT 'Количество продавцов: ' || COUNT(*)::text as info
FROM users WHERE user_type = 'merchant'

UNION ALL
SELECT 'Количество покупателей: ' || COUNT(*)::text
FROM users WHERE user_type = 'customer'

UNION ALL
SELECT 'Среднее количество товаров на продавца: ' || ROUND(AVG(product_count)::numeric, 2)::text
FROM (
    SELECT merch_id, COUNT(*) as product_count 
    FROM goods 
    GROUP BY merch_id
) as seller_stats

UNION ALL
SELECT 'Среднее количество заказов на покупателя: ' || ROUND(AVG(order_count)::numeric, 2)::text
FROM (
    SELECT user_id, COUNT(*) as order_count 
    FROM orders 
    GROUP BY user_id
) as customer_stats

UNION ALL
SELECT 'Средний рейтинг товаров: ' || ROUND(AVG(rating)::numeric, 2)::text
FROM reviews;