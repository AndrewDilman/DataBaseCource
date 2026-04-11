-- Генерация маленькой базы с богатыми связями для Neo4j
-- Быстрая генерация (~30 секунд), но с реалистичными связями

-- Очистка таблиц перед генерацией
TRUNCATE TABLE purchase_history CASCADE;
TRUNCATE TABLE reviews CASCADE;
TRUNCATE TABLE orders CASCADE;
TRUNCATE TABLE goods CASCADE;
TRUNCATE TABLE users CASCADE;
TRUNCATE TABLE categories CASCADE;
TRUNCATE TABLE addresses CASCADE;
ALTER SEQUENCE addresses_addr_id_seq RESTART WITH 1;
ALTER SEQUENCE categories_caty_id_seq RESTART WITH 1;
ALTER SEQUENCE users_user_id_seq RESTART WITH 1;
ALTER SEQUENCE goods_good_id_seq RESTART WITH 1;
ALTER SEQUENCE orders_id_seq RESTART WITH 1;
ALTER SEQUENCE reviews_id_seq RESTART WITH 1;
ALTER SEQUENCE purchase_history_id_seq RESTART WITH 1;

-- ===================== ФУНКЦИИ ГЕНЕРАЦИИ =====================

-- Случайное имя
CREATE OR REPLACE FUNCTION random_name() RETURNS TEXT AS $$
DECLARE
  first_names TEXT[] := ARRAY['Иван', 'Петр', 'Мария', 'Анна', 'Сергей', 'Ольга', 'Алексей', 'Елена', 'Дмитрий', 'Наталья'];
  last_names TEXT[] := ARRAY['Иванов', 'Петров', 'Сидоров', 'Кузнецов', 'Попов', 'Васильев', 'Смирнов', 'Новиков', 'Федоров', 'Морозов'];
BEGIN
  RETURN first_names[1 + floor(random() * array_length(first_names, 1))::int] || ' ' || 
         last_names[1 + floor(random() * array_length(last_names, 1))::int];
END;
$$ LANGUAGE plpgsql;

-- Название товара
CREATE OR REPLACE FUNCTION random_product_name() RETURNS TEXT AS $$
DECLARE
  prefixes TEXT[] := ARRAY['Умный', 'Профессиональный', 'Домашний', 'Портативный', 'Электронный'];
  products TEXT[] := ARRAY['смартфон', 'ноутбук', 'планшет', 'телевизор', 'наушники', 'часы', 'монитор', 'фотоаппарат'];
  brands TEXT[] := ARRAY['Samsung', 'Apple', 'Xiaomi', 'Sony', 'LG', 'Philips'];
BEGIN
  RETURN brands[1 + floor(random() * array_length(brands, 1))::int] || ' ' || 
         prefixes[1 + floor(random() * array_length(prefixes, 1))::int] || ' ' || 
         products[1 + floor(random() * array_length(products, 1))::int] || ' ' || 
         floor(random() * 100 + 1)::int;
END;
$$ LANGUAGE plpgsql;

-- ===================== ГЕНЕРАЦИЯ КАТЕГОРИЙ =====================
INSERT INTO categories (name) VALUES 
('Электроника'),
('Бытовая техника'),
('Компьютеры и ноутбуки'),
('Смартфоны и гаджеты'),
('Фото и видео'),
('Аудиотехника'),
('Игры и развлечения'),
('Кухонная техника'),
('Красота и здоровье'),
('Автотовары'),
('Спорт и отдых'),
('Книги'),
('Одежда и обувь'),
('Детские товары'),
('Садовый инвентарь')
ON CONFLICT (name) DO NOTHING;

-- ===================== ГЕНЕРАЦИЯ АДРЕСОВ =====================
INSERT INTO addresses (name) 
SELECT 'Город ' || generate_series || ', ул. Ленина, д. ' || (random() * 50 + 1)::int
FROM generate_series(1, 30);

-- ===================== ГЕНЕРАЦИЯ ПРОДАВЦОВ =====================
INSERT INTO users (password_hash, name, user_type)
SELECT 
  md5(random()::text),
  'Магазин "' || random_name() || '"',
  'merchant'
FROM generate_series(1, 30);

-- ===================== ГЕНЕРАЦИЯ ТОВАРОВ =====================
DO $$
DECLARE
  v_merch_id INTEGER;
  v_products_per_merchant INTEGER;
  v_category_id INTEGER;
BEGIN
  FOR v_merch_id IN SELECT user_id FROM users WHERE user_type = 'merchant' LOOP
    v_products_per_merchant := 15 + floor(random() * 6)::int;
    v_category_id := 1 + floor(random() * 15)::int;
    INSERT INTO goods (merch_id, caty_id, name)
    SELECT v_merch_id, v_category_id, random_product_name()
    FROM generate_series(1, v_products_per_merchant);
  END LOOP;
END $$;

-- ===================== ГЕНЕРАЦИЯ ПОКУПАТЕЛЕЙ =====================
INSERT INTO users (password_hash, name, user_type)
SELECT 
  md5(random()::text),
  random_name(),
  'customer'
FROM generate_series(1, 400);

-- ===================== ГЕНЕРАЦИЯ ЗАКАЗОВ =====================
DO $$
DECLARE
  v_customer_id INTEGER;
  v_order_count INTEGER;
  v_good_id INTEGER;
  v_goods_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_goods_count FROM goods;
  FOR v_customer_id IN SELECT user_id FROM users WHERE user_type = 'customer' LOOP
    v_order_count := floor(random() * 8)::int;
    FOR i IN 1..v_order_count LOOP
      v_good_id := 1 + floor(random() * v_goods_count)::int;
      INSERT INTO orders (user_id, good_id)
      VALUES (v_customer_id, v_good_id);
    END LOOP;
  END LOOP;
END $$;

-- ===================== ГЕНЕРАЦИЯ ОТЗЫВОВ =====================
INSERT INTO reviews (user_id, good_id, rating, comment)
SELECT 
  o.user_id,
  o.good_id,
  1 + floor(random() * 5)::int,
  CASE floor(random() * 5)::int
    WHEN 0 THEN 'Отличный товар! Рекомендую'
    WHEN 1 THEN 'Хорошее качество, доволен покупкой'
    WHEN 2 THEN 'Нормальный товар за свои деньги'
    WHEN 3 THEN 'Есть небольшие недочеты, но в целом неплохо'
    ELSE 'Не советую, качество оставляет желать лучшего'
  END
FROM orders o
WHERE random() < 0.3
ON CONFLICT (user_id, good_id) DO NOTHING;

-- ===================== ГЕНЕРАЦИЯ ИСТОРИИ ПОКУПОК =====================
INSERT INTO purchase_history (user_id, order_id)
SELECT user_id, id FROM orders;

-- ===================== СКЛАДЫ И ПУНКТЫ ВЫДАЧИ =====================
INSERT INTO warehouses (addr_id) SELECT addr_id FROM addresses ORDER BY random() LIMIT 10;
INSERT INTO pickup_points (addr_id) SELECT addr_id FROM addresses ORDER BY random() LIMIT 15;

-- ===================== СТАТИСТИКА =====================
SELECT 
  '=== СТАТИСТИКА БД ===' AS info,
  (SELECT COUNT(*) FROM users WHERE user_type = 'merchant') AS merchants,
  (SELECT COUNT(*) FROM users WHERE user_type = 'customer') AS customers,
  (SELECT COUNT(*) FROM goods) AS products,
  (SELECT COUNT(*) FROM orders) AS orders,
  (SELECT COUNT(*) FROM reviews) AS reviews;

-- Проверка связей для Neo4j
SELECT u.name AS merchant, COUNT(g.good_id) AS product_count
FROM users u
LEFT JOIN goods g ON u.user_id = g.merch_id
WHERE u.user_type = 'merchant'
GROUP BY u.user_id, u.name
ORDER BY product_count DESC
LIMIT 10;

SELECT u.name AS merchant, COUNT(DISTINCT g.caty_id) AS category_count
FROM users u
LEFT JOIN goods g ON u.user_id = g.merch_id
WHERE u.user_type = 'merchant'
GROUP BY u.user_id, u.name
ORDER BY category_count DESC
LIMIT 10;

SELECT u.name AS customer, COUNT(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
WHERE u.user_type = 'customer'
GROUP BY u.user_id, u.name
ORDER BY order_count DESC
LIMIT 10;

ANALYZE;
