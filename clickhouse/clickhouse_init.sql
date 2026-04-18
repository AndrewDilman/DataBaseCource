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

-- События по заказам
CREATE TABLE IF NOT EXISTS shop_analytics.order_events
(
    order_id UInt64,
    user_id UInt64,
    merchant_id UInt64,
    good_id UInt64,
    category_id UInt32,
    order_ts DateTime,
    price Float32
)
ENGINE = MergeTree()
ORDER BY (order_ts, category_id, merchant_id, good_id);

-- События по отзывам
CREATE TABLE IF NOT EXISTS shop_analytics.review_events
(
    review_id UInt64,
    order_id UInt64,
    user_id UInt64,
    good_id UInt64,
    merchant_id UInt64,
    category_id UInt32,
    rating UInt8,
    comment String,
    review_ts DateTime
)
ENGINE = MergeTree()
ORDER BY (review_ts, category_id, merchant_id, good_id);

-- Агрегаты по категориям
CREATE TABLE IF NOT EXISTS shop_analytics.category_daily_stats
(
    date Date,
    category_id UInt32,
    orders_count UInt64,
    reviewed_count UInt64,
    rating_sum UInt64,
    review_count UInt64
)
ENGINE = SummingMergeTree()
ORDER BY (date, category_id)
PARTITION BY toYYYYMM(date)
TTL date + INTERVAL 30 DAY;

-- Агрегаты по продавцам
CREATE TABLE IF NOT EXISTS shop_analytics.merchant_daily_stats
(
    date Date,
    merchant_id UInt64,
    orders_count UInt64,
    reviewed_count UInt64,
    rating_sum UInt64,
    review_count UInt64
)
ENGINE = SummingMergeTree()
ORDER BY (date, merchant_id);

-- Агрегаты по товарам
CREATE TABLE IF NOT EXISTS shop_analytics.product_stats
(
    good_id UInt64,
    category_id UInt32,
    merchant_id UInt64,
    total_orders UInt64,
    review_count UInt64,
    rating_sum UInt64
)
ENGINE = SummingMergeTree()
ORDER BY (category_id, good_id);

-- Материализованные виды
CREATE MATERIALIZED VIEW IF NOT EXISTS shop_analytics.mv_category_orders
TO shop_analytics.category_daily_stats
AS
SELECT
    toDate(order_ts) AS date,
    category_id,
    1 AS orders_count,
    0 AS reviewed_count,
    0 AS rating_sum,
    0 AS review_count
FROM shop_analytics.order_events;

CREATE MATERIALIZED VIEW IF NOT EXISTS shop_analytics.mv_category_reviews
TO shop_analytics.category_daily_stats
AS
SELECT
    toDate(review_ts) AS date,
    category_id,
    0 AS orders_count,
    1 AS reviewed_count,
    rating AS rating_sum,
    1 AS review_count
FROM shop_analytics.review_events;

CREATE MATERIALIZED VIEW IF NOT EXISTS shop_analytics.mv_merchant_orders
TO shop_analytics.merchant_daily_stats
AS
SELECT
    toDate(order_ts) AS date,
    merchant_id,
    1 AS orders_count,
    0 AS reviewed_count,
    0 AS rating_sum,
    0 AS review_count
FROM shop_analytics.order_events;

CREATE MATERIALIZED VIEW IF NOT EXISTS shop_analytics.mv_merchant_reviews
TO shop_analytics.merchant_daily_stats
AS
SELECT
    toDate(review_ts) AS date,
    merchant_id,
    0 AS orders_count,
    1 AS reviewed_count,
    rating AS rating_sum,
    1 AS review_count
FROM shop_analytics.review_events;

CREATE MATERIALIZED VIEW IF NOT EXISTS shop_analytics.mv_product_orders
TO shop_analytics.product_stats
AS
SELECT
    good_id,
    category_id,
    merchant_id,
    1 AS total_orders,
    0 AS review_count,
    0 AS rating_sum
FROM shop_analytics.order_events;

CREATE MATERIALIZED VIEW IF NOT EXISTS shop_analytics.mv_product_reviews
TO shop_analytics.product_stats
AS
SELECT
    good_id,
    category_id,
    merchant_id,
    0 AS total_orders,
    1 AS review_count,
    rating AS rating_sum
FROM shop_analytics.review_events;