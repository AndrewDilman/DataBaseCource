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