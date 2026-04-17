-- Генерация средней базы данных для PostgreSQL
-- Добавляет данные к существующим (не очищает)
-- Параметры: ~5000 пользователей, ~5000 товаров, ~20000 заказов

BEGIN;

-- ===================== ФУНКЦИИ ГЕНЕРАЦИИ =====================

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

CREATE OR REPLACE FUNCTION random_name() RETURNS TEXT AS $$
DECLARE
  first_names TEXT[] := ARRAY['Иван', 'Петр', 'Мария', 'Анна', 'Сергей', 'Ольга', 'Алексей', 'Елена', 'Дмитрий', 'Наталья', 'Андрей', 'Татьяна', 'Михаил', 'Светлана', 'Владимир', 'Юлия', 'Константин', 'Ирина', 'Николай', 'Оксана'];
  last_names TEXT[] := ARRAY['Иванов', 'Петров', 'Сидоров', 'Кузнецов', 'Попов', 'Васильев', 'Смирнов', 'Новиков', 'Федоров', 'Морозов', 'Волков', 'Алексеев', 'Лебедев', 'Семенов', 'Егоров', 'Захаров', 'Павлов', 'Орлов', 'Киселев', 'Макаров'];
BEGIN
  RETURN first_names[1 + floor(random() * array_length(first_names, 1))::int] || ' ' || 
         last_names[1 + floor(random() * array_length(last_names, 1))::int];
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION random_product_name() RETURNS TEXT AS $$
DECLARE
  prefixes TEXT[] := ARRAY['Умный', 'Профессиональный', 'Домашний', 'Портативный', 'Электронный', 'Цифровой', 'Беспроводной', 'Интеллектуальный', 'Компактный', 'Стильный', 'Мощный', 'Мини'];
  products TEXT[] := ARRAY['смартфон', 'ноутбук', 'планшет', 'телевизор', 'наушники', 'часы', 'монитор', 'фотоаппарат', 'принтер', 'роутер', 'микрофон', 'динамик', 'пылесос', 'чайник', 'блендер', 'кофеварка', 'миксер', 'утюг', 'фен', 'триммер'];
  brands TEXT[] := ARRAY['Samsung', 'Apple', 'Xiaomi', 'Sony', 'LG', 'Philips', 'Bosch', 'Canon', 'Nikon', 'Huawei', 'Lenovo', 'Asus', 'Acer', 'HP', 'Dell', 'Xiaomi', 'Realme', 'OnePlus', 'Motorola', 'POCO'];
BEGIN
  RETURN brands[1 + floor(random() * array_length(brands, 1))::int] || ' ' || 
         prefixes[1 + floor(random() * array_length(prefixes, 1))::int] || ' ' || 
         products[1 + floor(random() * array_length(products, 1))::int] || ' ' || 
         floor(random() * 9000 + 1000)::int;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION random_address() RETURNS TEXT AS $$
DECLARE
  cities TEXT[] := ARRAY['Москва', 'Санкт-Петербург', 'Новосибирск', 'Екатеринбург', 'Казань', 'Нижний Новгород', 'Челябинск', 'Самара', 'Омск', 'Ростов-на-Дону', 'Уфа', 'Волгоград', 'Пермь', 'Красноярск', 'Воронеж'];
  streets TEXT[] := ARRAY['Ленина', 'Пушкина', 'Гагарина', 'Советская', 'Мира', 'Кирова', 'Лесная', 'Центральная', 'Молодежная', 'Школьная', 'Набережная', 'Первомайск��я'];
  types TEXT[] := ARRAY['ул.', 'пр.', 'пер.', 'б-р', 'ш.'];
BEGIN
  RETURN cities[1 + floor(random() * array_length(cities, 1))::int] || ', ' || 
         types[1 + floor(random() * array_length(types, 1))::int] || ' ' || 
         streets[1 + floor(random() * array_length(streets, 1))::int] || ', д. ' || 
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
SELECT random_address()
FROM generate_series(1, 200);

-- ===================== ГЕНЕРАЦИЯ ПРОДАВЦОВ =====================
INSERT INTO users (password_hash, name, user_type)
SELECT 
  md5(random()::text),
  'Магазин "' || random_name() || '"',
  'merchant'
FROM generate_series(1, 100);

-- ===================== ГЕНЕРАЦИЯ ТОВАРОВ =====================
DO $$
DECLARE
  v_merch_id INTEGER;
  v_products_per_merchant INTEGER;
  v_category_id INTEGER;
  v_max_category_id INTEGER;
BEGIN
  SELECT MAX(caty_id) INTO v_max_category_id FROM categories;
  FOR v_merch_id IN SELECT user_id FROM users WHERE user_type = 'merchant' AND user_id > (SELECT COALESCE(MAX(user_id), 0) FROM users WHERE user_type = 'merchant' AND user_id NOT IN (SELECT user_id FROM users WHERE user_type = 'merchant' AND name LIKE 'Магазин%' ORDER BY user_id LIMIT 100)) LOOP
    v_products_per_merchant := 40 + floor(random() * 20)::int;
    v_category_id := 1 + floor(random() * v_max_category_id)::int;
    INSERT INTO goods (merch_id, caty_id, name)
    SELECT v_merch_id, (v_category_id - 1 + i) % v_max_category_id + 1, random_product_name()
    FROM generate_series(1, v_products_per_merchant) AS i;
  END LOOP;
END $$;

-- ===================== ГЕНЕРАЦИЯ ПОКУПАТЕЛЕЙ =====================
INSERT INTO users (password_hash, name, user_type)
SELECT 
  md5(random()::text),
  random_name(),
  'customer'
FROM generate_series(1, 4900);

-- ===================== СКЛАДЫ И ПУНКТЫ ВЫДАЧИ =====================
INSERT INTO warehouses (addr_id) 
SELECT addr_id FROM addresses ORDER BY random() LIMIT 30;

INSERT INTO pickup_points (addr_id) 
SELECT addr_id FROM addresses ORDER BY random() LIMIT 50;

COMMIT;

-- ===================== СТАТИСТИКА =====================
SELECT '=== СТАТИСТИКА БД ===' AS info;
SELECT (SELECT COUNT(*) FROM users WHERE user_type = 'merchant') AS merchants;
SELECT (SELECT COUNT(*) FROM users WHERE user_type = 'customer') AS customers;
SELECT (SELECT COUNT(*) FROM goods) AS products;
SELECT (SELECT COUNT(*) FROM orders) AS orders;
SELECT (SELECT COUNT(*) FROM reviews) AS reviews;

ANALYZE;