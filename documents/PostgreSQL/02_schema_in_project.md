# PostgreSQL - Схема в проекте

## Обзор

База данных `marketplace` содержит информацию о маркетплейсе: пользователях, товарах, заказах, отзывах и логистике.

## Диаграмма связей

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│ addresses │       │ categories│       │    users  │
├─────────────┤       ├─────────────┤       ├─────────────┤
│ addr_id(PK)│       │ caty_id(PK)│       │ user_id(PK)│
│ name      │       │ name      │◀──────│ merch_id  │
└─────┬─────┘       └───────────┘       │ user_type │
      │                                   └────┬─────┘
      │                                        │
┌─────▼──────────────────────┐                 │
│ warehouses , pickup_points │                 │
├───────────────────────────┤                 │
│       addr_id (FK)       │◀────────────────┘
└────────────┬──────────────┘
             │
             │ good_id, user_id
             ▼
       ┌─────────────┐       ┌─────────────┐
       │   goods   │       │   orders   │
       ├─────────────┤       ├─────────────┤
       │ good_id(PK)│       │ id (PK)    │
       │ merch_id(FK)│       │ user_id(FK) │
       │ caty_id(FK)│       │ good_id(FK) │
       └───────────┘       └──────┬──────┘
                                   │
       ┌──────────────────────────┬──▼──────────────────┐
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│  reviews   │       │purchase_hst│       │  (graph)  │
├─────────────┤       ├─────────────┤
│ id (PK)   │       │ id (PK)   │
│ user_id(FK)│       │ user_id   │
│ good_id(FK)│       │ order_id  │
│ rating    │       └───────────┘
│ comment  │
└─────────┘
```

## Таблицы

### addresses - Адреса

Таблица хранит адреса для пунктов выдачи и складов.

```sql
CREATE TABLE addresses (
    addr_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);
```

| Столбец | Тип | Ограничения | Описание |
|---------|-----|------------|----------|
| addr_id | SERIAL | PRIMARY KEY | Уникальный ID адреса |
| name | VARCHAR(255) | NOT NULL | Адрес (строка) |

### categories - Категории товаров

```sql
CREATE TABLE categories (
    caty_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);
```

| Сто��бец | Тип | Ограничения | Описание |
|---------|-----|------------|----------|
| caty_id | SERIAL | PRIMARY KEY | Уникальный ID категории |
| name | VARCHAR(100) | NOT NULL, UNIQUE | Название категории |

### users - Пользователи

Общая таблица для покупателей и продавцов.

```sql
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('customer', 'merchant'))
);
```

| Столбец | Тип | Ограничения | Описание |
|---------|-----|------------|----------|
| user_id | SERIAL | PRIMARY KEY | Уникальный ID пользователя |
| password_hash | VARCHAR(255) | NOT NULL | Хэш пароля |
| name | VARCHAR(100) | NOT NULL | Имя пользователя |
| user_type | VARCHAR(20) | NOT NULL, CHECK | Тип: 'customer' или 'merchant' |

**user_type:**
- `customer` - покупатель
- `merchant` - продавец

### goods - Товары

```sql
CREATE TABLE goods (
    good_id SERIAL PRIMARY KEY,
    merch_id INTEGER NOT NULL,
    caty_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    
    FOREIGN KEY (merch_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (caty_id) REFERENCES categories(caty_id) ON DELETE RESTRICT
);
```

| Столбец | Тип | Ограничения | Описание |
|---------|-----|------------|----------|
| good_id | SERIAL | PRIMARY KEY | Уникальный ID товара |
| merch_id | INTEGER | NOT NULL, FK → users.user_id | ID продавца |
| caty_id | INTEGER | NOT NULL, FK → categories.caty_id | ID категории |
| name | VARCHAR(255) | NOT NULL | Название товара |

**Внешние ключи:**
- `merch_id` → `users(user_id)` с каскадным удалением (при удалении продавца товары удаляются)
- `caty_id` → `categories(caty_id)` с ограничением (нельзя удалить категорию с товарами)

### orders - Заказы

```sql
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    good_id INTEGER NOT NULL,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (good_id) REFERENCES goods(good_id) ON DELETE RESTRICT
);
```

| Столбец | Тип | Ограничения | Описание |
|---------|-----|------------|----------|
| id | SERIAL | PRIMARY KEY | Уникальный ID заказа |
| user_id | INTEGER | NOT NULL, FK → users.user_id | ID покупателя |
| good_id | INTEGER | NOT NULL, FK → goods.good_id | ID товара |

### reviews - Отзывы

```sql
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    good_id INTEGER NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (good_id) REFERENCES goods(good_id) ON DELETE CASCADE,
    UNIQUE(user_id, good_id)
);
```

| Столбец | Тип | Ограничения | Описание |
|---------|-----|------------|----------|
| id | SERIAL | PRIMARY KEY | Уникальный ID отзыва |
| user_id | INTEGER | NOT NULL, FK → users.user_id, UNIQUE(с good_id) | ID пользователя |
| good_id | INTEGER | NOT NULL, FK → goods.good_id, UNIQUE(с user_id) | ID товара |
| rating | INTEGER | CHECK (1-5) | Рейтинг (1-5 звёзд) |
| comment | TEXT | - | Текст отзыва |

**Ограничение:** UNIQUE(user_id, good_id) - один отзыв на товар от пользователя.

### purchase_history - История покуп��к

```sql
CREATE TABLE purchase_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    order_id INTEGER NOT NULL,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);
```

| Столбец | Тип | Ограничения | Описание |
|---------|-----|------------|----------|
| id | SERIAL | PRIMARY KEY | Уникальный ID |
| user_id | INTEGER | NOT NULL, FK → users.user_id | ID покупателя |
| order_id | INTEGER | NOT NULL, FK → orders.id | ID заказа |

### pickup_points - Пункты выдачи

```sql
CREATE TABLE pickup_points (
    id SERIAL PRIMARY KEY,
    addr_id INTEGER NOT NULL,
    
    FOREIGN KEY (addr_id) REFERENCES addresses(addr_id) ON DELETE CASCADE
);
```

| Столбец | Тип | Ограничения | Описание |
|---------|-----|------------|----------|
| id | SERIAL | PRIMARY KEY | Уникальный ID |
| addr_id | INTEGER | NOT NULL, FK → addresses.addr_id | ID адреса |

### warehouses - Склады

```sql
CREATE TABLE warehouses (
    id SERIAL PRIMARY KEY,
    addr_id INTEGER NOT NULL,
    
    FOREIGN KEY (addr_id) REFERENCES addresses(addr_id) ON DELETE CASCADE
);
```

| Столбец | Тип | Ограничения | Описание |
|---------|-----|------------|----------|
| id | SERIAL | PRIMARY KEY | Уникальный ID |
| addr_id | INTEGER | NOT NULL, FK → addresses.addr_id | ID адреса |

## Индексы

Для улучшения производительности созданы индексы:

```sql
-- Индексы для товаров
CREATE INDEX idx_goods_merch_id ON goods(merch_id);
CREATE INDEX idx_goods_caty_id ON goods(caty_id);

-- Индексы для заказов
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_good_id ON orders(good_id);

-- Индексы для отзывов
CREATE INDEX idx_reviews_user_id ON reviews(user_id);
CREATE INDEX idx_reviews_good_id ON reviews(good_id);

-- Индекс для типа пользователя
CREATE INDEX idx_users_user_type ON users(user_type);
```

## Представления

### goods_view - Просмотр товаров с данными продавца и категории

```sql
CREATE VIEW goods_view AS
SELECT 
    g.good_id,
    g.name as product_name,
    u.name as merchant_name,
    c.name as category_name
FROM goods g
JOIN users u ON g.merch_id = u.user_id
JOIN categories c ON g.caty_id = c.caty_id;
```

## Публикация для репликации

Создаётся для синхронизации с подписчиком:

```sql
CREATE PUBLICATION marketplace_all_tables FOR TABLE 
    addresses, 
    categories, 
    users, 
    goods, 
    orders, 
    reviews, 
    purchase_history, 
    pickup_points, 
    warehouses;
```

## Начальные данные

См. [seed_data.sql](../../seed_data.sql) - скрипт заполнения тестовыми данными:
- 10 адресов
- 10 категорий
- 15 пользователей (5 продавцов, 10 покупателей)
- 25 товаров
- 26 заказов
- 10 отзывов

## Подключение

```bash
psql -h localhost -p 5433 -U admin -d marketplace
```

- Хост: localhost
- Порт: 5433
- Пользователь: admin
- Пароль: 123
- База данных: marketplace

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия PostgreSQL
- [03_operations.md](03_operations.md) - Операции с данными
- [04_replication.md](04_replication.md) - Логическая репликация
- [05_partitioning.md](05_partitioning.md) - Партиционирование