-- Общая статистика продаж за последний месяц
SELECT
    count() AS total_orders,
    sum(price) AS total_revenue,
    avg(price) AS avg_order_value,
    count(DISTINCT user_id) AS unique_customers
FROM shop_analytics.order_events
WHERE order_ts >= today() - INTERVAL 30 DAY;

-- Топ-10 категорий по количеству заказов и выручке
SELECT
    category_id,
    sum(orders_count) AS total_orders,
    sum(reviewed_count) AS total_reviews,
    round(avg(rating_sum / review_count), 2) AS avg_rating
FROM shop_analytics.category_daily_stats
WHERE date >= today() - INTERVAL 30 DAY
GROUP BY category_id
ORDER BY total_orders DESC
LIMIT 5;

-- Топ товаров по продажам и отзывам
SELECT
    good_id,
    total_orders,
    review_count,
    round(rating_sum / review_count, 2) AS avg_rating
FROM shop_analytics.product_stats
WHERE review_count > 0
ORDER BY total_orders DESC, avg_rating DESC
LIMIT 20;

-- Частота оценок по рейтингу за последний месяц
SELECT
    rating,
    count() AS count_reviews
FROM shop_analytics.review_events
WHERE review_ts >= today() - INTERVAL 30 DAY
GROUP BY rating
ORDER BY rating DESC;

-- Анализ повторных покупок клиентов
SELECT
    user_id,
    count(DISTINCT order_id) AS total_orders_per_user,
    sum(price) AS total_spent
FROM shop_analytics.order_events
WHERE order_ts >= today() - INTERVAL 90 DAY
GROUP BY user_id
HAVING total_orders_per_user > 1
ORDER BY total_spent DESC
LIMIT 50;

-- Продавцы с низким рейтингом (менее 3.0)
SELECT
    merchant_id,
    sum(orders_count) AS total_orders,
    sum(reviewed_count) AS total_reviews,
    round(avg(rating_sum / review_count), 2) AS avg_rating
FROM shop_analytics.merchant_daily_stats
WHERE date >= today() - INTERVAL 30 DAY
GROUP BY merchant_id
HAVING total_reviews > 10 AND avg_rating < 3.0
ORDER BY avg_rating ASC;