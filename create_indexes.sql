-- Индексы для оптимизации запросов с большими данными

-- Основные индексы для внешних ключей
CREATE INDEX CONCURRENTLY idx_goods_merch_id ON goods(merch_id);
CREATE INDEX CONCURRENTLY idx_goods_caty_id ON goods(caty_id);
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders(user_id);
CREATE INDEX CONCURRENTLY idx_orders_good_id ON orders(good_id);
CREATE INDEX CONCURRENTLY idx_reviews_user_id ON reviews(user_id);
CREATE INDEX CONCURRENTLY idx_reviews_good_id ON reviews(good_id);
CREATE INDEX CONCURRENTLY idx_users_user_type ON users(user_type);

-- Составные индексы для часто используемых запросов
CREATE INDEX CONCURRENTLY idx_orders_user_good ON orders(user_id, good_id);
CREATE INDEX CONCURRENTLY idx_reviews_user_good ON reviews(user_id, good_id);
CREATE INDEX CONCURRENTLY idx_goods_merch_caty ON goods(merch_id, caty_id);

-- Индексы для агрегирующих запросов
CREATE INDEX CONCURRENTLY idx_orders_date_user ON orders(user_id);
CREATE INDEX CONCURRENTLY idx_reviews_rating_good ON reviews(good_id, rating);

-- Частичные индексы для оптимизации
CREATE INDEX CONCURRENTLY idx_merchant_users ON users(user_id) WHERE user_type = 'merchant';
CREATE INDEX CONCURRENTLY idx_customer_users ON users(user_id) WHERE user_type = 'customer';
CREATE INDEX CONCURRENTLY idx_active_orders ON orders(user_id) WHERE user_id IS NOT NULL;

-- Индексы для оконных функций
CREATE INDEX CONCURRENTLY idx_goods_orders_count ON goods(good_id);
CREATE INDEX CONCURRENTLY idx_users_orders_count ON users(user_id);

-- Дополнительные индексы для оптимизации с учетом увеличенного объема данных

-- Индексы для ускорения JOIN операций в сложных запросах
CREATE INDEX CONCURRENTLY idx_purchase_history_user_order ON purchase_history(user_id, order_id);
CREATE INDEX CONCURRENTLY idx_purchase_history_order_id ON purchase_history(order_id);

-- Индексы для оптимизации агрегирующих запросов из business_cases.sql
CREATE INDEX CONCURRENTLY idx_orders_user_good ON orders(user_id, good_id);
CREATE INDEX CONCURRENTLY idx_reviews_user_good_rating ON reviews(user_id, good_id, rating);

-- Индексы для оптимизации оконных функций
CREATE INDEX CONCURRENTLY idx_orders_user_id_created ON orders(user_id);
CREATE INDEX CONCURRENTLY idx_goods_cat_id ON goods(caty_id);

-- Индексы для ускорения запросов с сортировкой
CREATE INDEX CONCURRENTLY idx_orders_id ON orders(id);
CREATE INDEX CONCURRENTLY idx_reviews_id ON reviews(id);
CREATE INDEX CONCURRENTLY idx_purchase_history_id ON purchase_history(id);

-- Индексы для оптимизации запросов с GROUP BY
CREATE INDEX CONCURRENTLY idx_users_type_name ON users(user_type, name);
CREATE INDEX CONCURRENTLY idx_goods_merchant_name ON goods(merch_id, name);
