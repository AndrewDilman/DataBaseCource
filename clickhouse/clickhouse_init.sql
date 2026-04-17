-- Даём время на инициализацию пользователя
SELECT sleep(3);

CREATE DATABASE IF NOT EXISTS shop_analytics;

-- Основная таблица фактов
CREATE TABLE IF NOT EXISTS shop_analytics.order_analytics
(
    order_id UInt64,
    user_id UInt64,
    merchant_id UInt64,
    good_id UInt64,
    category_id UInt32,
    category_name String,
    merchant_name String,
    good_name String,
    rating UInt8,
    has_review UInt8,
    order_date Date,
    order_timestamp DateTime
)
ENGINE = MergeTree()
ORDER BY (order_date, category_id, merchant_id, good_id);

-- Агрегаты по категориям
CREATE TABLE IF NOT EXISTS shop_analytics.category_daily_stats
(
    date Date,
    category_id UInt32,
    category_name String,
    orders_count UInt64,
    avg_rating Float32,
    reviewed_count UInt64
)
ENGINE = SummingMergeTree()
ORDER BY (date, category_id);

-- Агрегаты по продавцам
CREATE TABLE IF NOT EXISTS shop_analytics.merchant_daily_stats
(
    date Date,
    merchant_id UInt64,
    merchant_name String,
    orders_count UInt64,
    avg_rating Float32,
    reviewed_orders UInt64
)
ENGINE = SummingMergeTree()
ORDER BY (date, merchant_id);

-- Агрегаты по товарам
CREATE TABLE IF NOT EXISTS shop_analytics.product_stats
(
    good_id UInt64,
    good_name String,
    category_id UInt32,
    merchant_id UInt64,
    total_orders UInt64,
    avg_rating Float32,
    review_count UInt64
)
ENGINE = SummingMergeTree()
ORDER BY (category_id, good_id);