-- Функция для генерации случайных строк
CREATE OR REPLACE FUNCTION random_string(length INTEGER) RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  result TEXT := '';
  i INTEGER := 0;
BEGIN
  FOR i IN 1..length LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Функция для генерации случайных имен
CREATE OR REPLACE FUNCTION random_name() RETURNS TEXT AS $$
DECLARE
  first_names TEXT[] := ARRAY['Иван', 'Петр', 'Мария', 'Анна', 'Сергей', 'Ольга', 'Алексей', 'Елена', 'Дмитрий', 'Наталья', 'Андрей', 'Татьяна', 'Михаил', 'Светлана', 'Владимир'];
  last_names TEXT[] := ARRAY['Иванов', 'Петров', 'Сидоров', 'Кузнецов', 'Попов', 'Васильев', 'Смирнов', 'Новиков', 'Федоров', 'Морозов', 'Волков', 'Алексеев', 'Лебедев', 'Семенов', 'Егоров'];
BEGIN
  RETURN first_names[floor(random() * array_length(first_names, 1) + 1)] || ' ' || last_names[floor(random() * array_length(last_names, 1) + 1)];
END;
$$ LANGUAGE plpgsql;

-- Функция для генерации названий товаров
CREATE OR REPLACE FUNCTION random_product_name() RETURNS TEXT AS $$
DECLARE
  prefixes TEXT[] := ARRAY['Умный', 'Профессиональный', 'Домашний', 'Портативный', 'Электронный', 'Цифровой', 'Беспроводной', 'Интеллектуальный', 'Компактный', 'Стильный'];
  products TEXT[] := ARRAY['смартфон', 'ноутбук', 'планшет', 'телевизор', 'наушники', 'часы', 'монитор', 'фотоаппарат', 'принтер', 'роутер', 'микрофон', 'динамик', 'пылесос', 'чайник', 'блендер'];
  brands TEXT[] := ARRAY['Samsung', 'Apple', 'Xiaomi', 'Sony', 'LG', 'Philips', 'Bosch', 'Canon', 'Nikon', 'Huawei', 'Lenovo', 'Asus', 'Acer', 'HP', 'Dell'];
BEGIN
  RETURN brands[floor(random() * array_length(brands, 1) + 1)] || ' ' || 
         prefixes[floor(random() * array_length(prefixes, 1) + 1)] || ' ' || 
         products[floor(random() * array_length(products, 1) + 1)] || ' ' || 
         floor(random() * 9000 + 1000)::text;
END;
$$ LANGUAGE plpgsql;

-- Функция для генерации названий адресов
CREATE OR REPLACE FUNCTION random_address() RETURNS TEXT AS $$
DECLARE
  cities TEXT[] := ARRAY['Москва', 'Санкт-Петербург', 'Новосибирск', 'Екатеринбург', 'Казань', 'Нижний Новгород', 'Челябинск', 'Самара', 'Омск', 'Ростов-на-Дону'];
  streets TEXT[] := ARRAY['Ленина', 'Пушкина', 'Гагарина', 'Советская', 'Мира', 'Кирова', 'Лесная', 'Центральная', 'Молодежная', 'Школьная'];
  types TEXT[] := ARRAY['ул.', 'пр.', 'пер.', 'б-р', 'ш.'];
BEGIN
  RETURN cities[floor(random() * array_length(cities, 1) + 1)] || ', ' || 
         types[floor(random() * array_length(types, 1) + 1)] || ' ' || 
         streets[floor(random() * array_length(streets, 1) + 1)] || ', д. ' || 
         floor(random() * 100 + 1)::text;
END;
$$ LANGUAGE plpgsql;

-- Генерация категорий (фиксированный набор)
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
('Автотовары')
ON CONFLICT (name) DO NOTHING;

-- Генерация адресов (1000 записей)
INSERT INTO addresses (name)
SELECT random_address()
FROM generate_series(1, 1000);

-- Генерация пользователей (1 миллион записей)
INSERT INTO users (password_hash, name, user_type)
SELECT 
  md5(random()::text), -- хэш пароля
  random_name(), -- имя
  CASE WHEN random() < 0.2 THEN 'merchant' ELSE 'customer' END -- тип пользователя
FROM generate_series(1, 1000000);

-- Генерация товаров (500 тысяч записей) с равномерным распределением по продавцам
INSERT INTO goods (merch_id, caty_id, name)
WITH merchants_shuffled AS (
  SELECT 
    u.user_id,
    row_number() OVER (ORDER BY random()) AS rn,
    COUNT(*) OVER () AS total_merchants
  FROM users u
  WHERE u.user_type = 'merchant'
), quotas AS (
  SELECT 
    user_id,
    rn AS merchant_rn,
    (500000 / total_merchants) + CASE WHEN rn <= (500000 % total_merchants) THEN 1 ELSE 0 END AS goods_quota
  FROM merchants_shuffled
), expanded AS (
  SELECT 
    q.user_id AS merch_id,
    q.merchant_rn,
    generate_series(1, q.goods_quota) AS n
  FROM quotas q
), categories_enum AS (
  SELECT 
    c.caty_id,
    row_number() OVER (ORDER BY c.caty_id) AS rn,
    COUNT(*) OVER () AS total_categories
  FROM categories c
)
SELECT 
  e.merch_id,
  ce.caty_id,
  random_product_name() AS name
FROM expanded e
JOIN categories_enum ce
  ON ce.rn = 1 + (((e.merchant_rn + e.n - 2)) % ce.total_categories);

-- Генерация заказов (увеличено до 3.5 миллионов записей)
INSERT INTO orders (user_id, good_id)
WITH customers AS (
  SELECT user_id
  FROM users
  WHERE user_type = 'customer'
),
-- Создаем план для более высокой частоты заказов
orders_plan AS (
  SELECT 
    user_id,
    -- новое распределение: 5% — 0 заказов, 10% — 1, 10% — 2, 15% — 3, 15% — 4, 15% — 5, 10% — 6-10, 10% — 11-20, 5% — 21-30
    CASE 
      WHEN r < 0.05 THEN 0
      WHEN r < 0.15 THEN 1
      WHEN r < 0.25 THEN 2
      WHEN r < 0.40 THEN 3
      WHEN r < 0.55 THEN 4
      WHEN r < 0.70 THEN 5
      WHEN r < 0.80 THEN (random() * 5 + 6)::integer  -- 6-10 заказов
      WHEN r < 0.90 THEN (random() * 5 + 11)::integer -- 11-15 заказов
      ELSE (random() * 10 + 21)::integer              -- 21-30 заказов
    END AS orders_count
  FROM (
    SELECT user_id, random() AS r FROM customers
 ) t
),
expanded AS (
  SELECT user_id, generate_series(1, orders_count) AS n
  FROM orders_plan
  WHERE orders_count > 0
),
orders_candidates AS (
  -- Детерминированный выбор товара по хешу (равномерно по всему каталогу)
  WITH goods_enum AS (
    SELECT good_id, row_number() OVER (ORDER BY good_id) AS rn
    FROM goods
  ), goods_count AS (
    SELECT COUNT(*) AS cnt FROM goods
 )
  SELECT 
    e.user_id,
    ge.good_id
  FROM expanded e
 CROSS JOIN goods_count gc
  JOIN goods_enum ge
    ON ge.rn = 1 + (((hashtext(e.user_id::text || ':' || e.n::text)) & 2147483647) % gc.cnt)
)
SELECT user_id, good_id
FROM orders_candidates
ORDER BY random()
LIMIT 3500000;  -- Увеличено до 3.5 миллионов

-- Генерация истории покупок (дублирует данные из заказов, но с дополнительной структурой)
INSERT INTO purchase_history (user_id, order_id)
SELECT 
  user_id,
  id
FROM orders
ORDER BY random()
LIMIT 300000; -- Ограничение до 3 миллионов записей для разнообразия

-- Генерация пунктов выдачи (200 записей)
INSERT INTO pickup_points (addr_id)
SELECT addr_id
FROM addresses
ORDER BY random()
LIMIT 200;

-- Генерация складов (50 записей)
INSERT INTO warehouses (addr_id)
SELECT addr_id
FROM addresses
ORDER BY random()
LIMIT 50;

-- Проверим сколько уникальных пар у нас есть
SELECT COUNT(*) as unique_user_good_pairs FROM (
    SELECT DISTINCT user_id, good_id FROM orders
    WHERE user_id IN (SELECT user_id FROM users WHERE user_type = 'customer')
) AS unique_pairs;

-- Генерация отзывов (случайно для части уникальных покупок)
INSERT INTO reviews (user_id, good_id, rating, comment)
WITH unique_orders AS (
    SELECT DISTINCT user_id, good_id
    FROM orders 
    WHERE user_id IN (SELECT user_id FROM users WHERE user_type = 'customer')
),
sampled_reviews AS (
    SELECT user_id, good_id
    FROM unique_orders
    WHERE random() < 0.35 -- ~35% покупок получают отзыв
)
SELECT 
    user_id,
    good_id,
    (random() * 4 + 1)::integer as rating,
    CASE (random() * 4)::integer
        WHEN 0 THEN 'Отличный товар! Рекомендую'
        WHEN 1 THEN 'Хорошее качество, доволен покупкой'
        WHEN 2 THEN 'Нормальный товар за свои деньги'
        WHEN 3 THEN 'Есть небольшие недочеты, но в целом неплохо'
        ELSE 'Не советую, качество оставляет желать лучшего'
    END as comment
FROM sampled_reviews
ON CONFLICT (user_id, good_id) DO NOTHING;

-- Обновление статистики для оптимизатора запросов
ANALYZE;

-- Вывод статистики
SELECT 
  (SELECT COUNT(*) FROM users) as total_users,
  (SELECT COUNT(*) FROM users WHERE user_type = 'customer') as customers,
  (SELECT COUNT(*) FROM users WHERE user_type = 'merchant') as merchants,
  (SELECT COUNT(*) FROM goods) as total_goods,
  (SELECT COUNT(*) FROM orders) as total_orders,
  (SELECT COUNT(*) FROM reviews) as total_reviews,
  (SELECT COUNT(*) FROM purchase_history) as total_purchase_history;
