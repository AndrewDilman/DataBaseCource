-- 1. Таблица адресов (базовая таблица для пунктов выдачи и складов)
CREATE TABLE addresses (
    addr_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

-- 2. Таблица категорий товаров
CREATE TABLE categories (
    caty_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

-- 3. Таблица пользователей (общая для покупателей и продавцов)
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('customer', 'merchant'))
);

-- 4. Таблица товаров
CREATE TABLE goods (
    good_id SERIAL PRIMARY KEY,
    merch_id INTEGER NOT NULL,
    caty_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    
    FOREIGN KEY (merch_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (caty_id) REFERENCES categories(caty_id) ON DELETE RESTRICT
);

-- 5. Таблица заказов
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    good_id INTEGER NOT NULL,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (good_id) REFERENCES goods(good_id) ON DELETE RESTRICT
);

-- 6. Таблица отзывов
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    good_id INTEGER NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (good_id) REFERENCES goods(good_id) ON DELETE CASCADE,
    UNIQUE(user_id, good_id) -- один отзыв на товар от пользователя
);

-- 7. Таблица истории покупок
CREATE TABLE purchase_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    order_id INTEGER NOT NULL,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

-- 8. Таблица пунктов выдачи
CREATE TABLE pickup_points (
    id SERIAL PRIMARY KEY,
    addr_id INTEGER NOT NULL,
    
    FOREIGN KEY (addr_id) REFERENCES addresses(addr_id) ON DELETE CASCADE
);

-- 9. Таблица складов
CREATE TABLE warehouses (
    id SERIAL PRIMARY KEY,
    addr_id INTEGER NOT NULL,
    
    FOREIGN KEY (addr_id) REFERENCES addresses(addr_id) ON DELETE CASCADE
);

-- Создаем индексы для улучшения производительности
CREATE INDEX idx_goods_merch_id ON goods(merch_id);
CREATE INDEX idx_goods_caty_id ON goods(caty_id);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_good_id ON orders(good_id);
CREATE INDEX idx_reviews_user_id ON reviews(user_id);
CREATE INDEX idx_reviews_good_id ON reviews(good_id);
CREATE INDEX idx_users_user_type ON users(user_type);

-- Исправленное представление (убраны отсутствующие поля)
CREATE VIEW goods_view AS
SELECT 
    g.good_id,
    g.name as product_name,
    u.name as merchant_name,
    c.name as category_name
FROM goods g
JOIN users u ON g.merch_id = u.user_id
JOIN categories c ON g.caty_id = c.caty_id;