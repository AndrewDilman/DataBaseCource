# Neo4j - Сложные запросы

## Введение

Этот документ содержит подробное руководство по составлению запросов в Neo4j - от простых к продвинутым. Предполагается, что в базе есть данные marketplace:

- **User** (покупатели и продавцы)
- **Product** (товары)  
- **Category** (категории)
- **SOLD_BY** (товар продаётся продавцом)
- **IN_CATEGORY** (товар в категории)
- **BOUGHT** (покупатель купил товар)
- **REVIEWED** (покупатель оставил отзыв)

---

## Уровень 1: Базовые запросы

### 1.1 Простой MATCH

Найти все узлы определённого типа:

```cypher
MATCH (u:User) RETURN u;
MATCH (p:Product) RETURN p;
MATCH (c:Category) RETURN c;
```

### 1.2 MATCH с RETURN

Вернуть только нужные свойства:

```cypher
MATCH (u:User) RETURN u.name, u.type;
MATCH (p:Product) RETURN p.name, p.productId;
```

### 1.3 MATCH по конкретному значению

```cypher
MATCH (u:User {userId: 1}) RETURN u;
MATCH (p:Product {name: 'Samsung Умный смартфон 2024'}) RETURN p;
```

### 1.4 ORDER BY - сортировка

```cypher
MATCH (u:User) RETURN u.name ORDER BY u.name;
MATCH (p:Product) RETURN p.name ORDER BY p.name DESC;
```

### 1.5 LIMIT - ограничение количества

```cypher
MATCH (u:User) RETURN u LIMIT 10;
MATCH (p:Product) RETURN p.name ORDER BY p.name LIMIT 5;
```

---

## Уровень 2: Фильтрация с WHERE

### 2.1 WHERE с простым условием

```cypher
MATCH (u:User) WHERE u.type = 'merchant' RETURN u.name;
```

### 2.2 WHERE с числовыми условиями

```cypher
-- Найти товары с рейтингом >= 4
MATCH (u:User)-[r:REVIEWED]->(p:Product)
WHERE r.rating >= 4
RETURN p.name, r.rating;
```

### 2.3 WHERE с несколькими условиями (AND)

```cypher
MATCH (u:User) 
WHERE u.type = 'customer' AND u.name STARTS WITH 'А'
RETURN u.name;
```

### 2.4 WHERE с OR

```cypher
MATCH (p:Product)
WHERE p.name CONTAINS 'Samsung' OR p.name CONTAINS 'Apple'
RETURN p.name;
```

### 2.5 WHERE с NOT

```cypher
-- Найти товары без отзывов
MATCH (p:Product)
WHERE NOT (p)<-[:REVIEWED]-()
RETURN p.name;
```

### 2.6 Фильтрация по списку (IN)

```cypher
MATCH (u:User)
WHERE u.userId IN [1, 2, 3, 10, 20]
RETURN u.name;
```

---

## Уровень 3: Работа со связями

### 3.1 Направленные связи

```cypher
-- Товар -> продавец
MATCH (p:Product)-[:SOLD_BY]->(u:User)
RETURN p.name, u.name;
```

### 3.2 Обратное направление

```cypher
-- Продавец -> товар
MATCH (u:User)-[:SOLD_BY]->(p:Product)
RETURN u.name, p.name;
```

### 3.3 Связь любого направления

```cypher
MATCH (u:User)--(p:Product)
RETURN u.name, p.name;
```

### 3.4 Несколько связей подряд

```cypher
-- Покупатель -> товар -> категория
MATCH (c:User)-[:BOUGHT]->(p:Product)-[:IN_CATEGORY]->(cat:Category)
RETURN c.name, p.name, cat.name;
```

### 3.5 variable length paths

```cypher
-- Найти всех, кто связан через любой путь
MATCH (a:User)-[*]->(b:User)
RETURN a.name, b.name;
```

---

## Уровень 4: Агрегации

### 4.1 COUNT - подсчёт

```cypher
MATCH (u:User) RETURN count(u);
```

### 4.2 GROUP BY с COUNT

```cypher
MATCH (u:User)-[:BOUGHT]->(p:Product)
RETURN u.name, count(p) as orders
ORDER BY orders DESC;
```

### 4.3 SUM - сумма

```cypher
MATCH (u:User)-[b:BOUGHT]->()
RETURN u.name, sum(b.count) as totalSpent
ORDER BY totalSpent DESC;
```

### 4.4 AVG - среднее

```cypher
MATCH (u:User)-[r:REVIEWED]->(p:Product)
RETURN avg(r.rating) as avgRating;
```

### 4.5 MIN/MAX

```cypher
MATCH (u:User)-[r:REVIEWED]->(p:Product)
RETURN min(r.rating) as minRating, max(r.rating) as maxRating;
```

### 4.6 COLLECT - собрать в список

```cypher
MATCH (c:Category)<-[:IN_CATEGORY]-(p:Product)
RETURN c.name, collect(p.name) as products;
```

### 4.7 Агрегация по нескольким полям

```cypher
MATCH (u:User)-[b:BOUGHT]->(p:Product)
RETURN u.name, p.categoryId, sum(b.count) as total
ORDER BY total DESC;
```

---

## Уровень 5: WITH - передача данных

WITH позволяет передавать промежуточные результаты между частями запроса.

### 5.1 Простой WITH

```cypher
MATCH (u:User)
WITH u.name as userName
RETURN userName ORDER BY userName;
```

### 5.2 WITH после агрегации

```cypher
MATCH (u:User)-[b:BOUGHT]->(p:Product)
WITH u, sum(b.count) as totalSpent
WHERE totalSpent > 100
RETURN u.name, totalSpent;
```

### 5.3 WITH для топ-N

```cypher
MATCH (u:User)-[b:BOUGHT]->(p:Product)
WITH u, sum(b.count) as totalSpent
ORDER BY totalSpent DESC
LIMIT 10
RETURN u.name, totalSpent;
```

### 5.4 WITH для вычислений

```cypher
MATCH (u:User)-[r:REVIEWED]->(p:Product)
WITH u, avg(r.rating) as avgRating
WHERE avgRating > 3
RETURN u.name, avgRating;
```

### 5.5 WITH несколько переменных

```cypher
MATCH (u:User)-[b:BOUGHT]->(p:Product)
WITH u.name as customer, p.categoryId as cat, sum(b.count) as total
RETURN customer, cat, total
ORDER BY total DESC;
```

---

## Уровень 6: OPTIONAL MATCH

### 6.1 OPTIONAL MATCH с NULL

```cypher
MATCH (u:User)
OPTIONAL MATCH (u)-[:BOUGHT]->(p:Product)
RETURN u.name, p.name;
```

### 6.2 COALESCE для NULL

```cypher
MATCH (u:User)
OPTIONAL MATCH (u)-[r:REVIEWED]->(p:Product)
RETURN u.name, coalesce(r.rating, 0) as rating;
```

### 6.3 OPTIONAL MATCH с COUNT

```cypher
MATCH (u:User)
OPTIONAL MATCH (u)-[:BOUGHT]->(p:Product)
RETURN u.name, count(p) as orders;
```

---

## Уровень 7: Сложные паттерны

### 7.1 Паттерн "продавец - товары в категории"

```cypher
MATCH (m:User {type:'merchant'})<-[:SOLD_BY]-(p:Product)-[:IN_CATEGORY]->(c:Category)
RETURN m.name as merchant, c.name as category, count(p) as productCount
ORDER BY productCount DESC;
```

### 7.2 Паттерн "общие покупки"

```cypher
-- Найти товары, которые покупали оба пользователя
MATCH (u1:User {userId: 1})-[b1:BOUGHT]->(p:Product)<-[b2:BOUGHT]-(u2:User {userId: 2})
RETURN p.name, b1.count + b2.count as totalBought;
```

### 7.3 Паттерн "товары без отзывов"

```cypher
MATCH (p:Product)
WHERE NOT (p)<-[:REVIEWED]-()
RETURN p.name;
```

### 7.4 Паттерн "категории с лучшим рейтингом"

```cypher
MATCH (c:Category)<-[:IN_CATEGORY]-(p:Product)<-[r:REVIEWED]-()
RETURN c.name, avg(r.rating) as avgRating, count(r) as reviewCount
ORDER BY avgRating DESC;
```

### 7.5 Паттерн "активные покупатели"

```cypher
MATCH (c:User {type:'customer'})-[b:BOUGHT]->(p:Product)
WITH c, sum(b.count) as total
WHERE total > 5
RETURN c.name, total
ORDER BY total DESC;
```

---

## Уровень 8: Подзапросы EXISTS

### 8.1 EXISTS в WHERE

```cypher
MATCH (p:Product)
WHERE EXISTS { (p)<-[:REVIEWED]-() }
RETURN p.name;
```

### 8.2 NOT EXISTS

```cypher
MATCH (p:Product)
WHERE NOT EXISTS { (p)<-[:BOUGHT]-() }
RETURN p.name;
```

### 8.3 EXISTS с условием

```cypher
MATCH (p:Product)
WHERE EXISTS { (p)<-[r:REVIEWED]-() WHERE r.rating >= 4 }
RETURN p.name;
```

---

## Уровень 9: Продвинутый анализ

### 9.1 Топ-N категорий по товарам

```cypher
MATCH (c:Category)<-[:IN_CATEGORY]-(p:Product)
RETURN c.name, count(p) as productCount
ORDER BY productCount DESC
LIMIT 10;
```

### 9.2 Топ-N продавцов по обороту

```cypher
MATCH (m:User {type:'merchant'})<-[:SOLD_BY]-(p:Product)<-[b:BOUGHT]-(c:User)
WITH m, sum(b.count) as totalSold
RETURN m.name, totalSold
ORDER BY totalSold DESC
LIMIT 10;
```

### 9.3 Анализ конкурентов (один товар у нескольких продавцов)

```cypher
MATCH (p:Product)<-[:SOLD_BY]-(m:User)
WITH p, collect(m.name) as merchants, count(m) as sellerCount
WHERE sellerCount > 1
RETURN p.name, merchants, sellerCount;
```

### 9.4 Сегментация покупателей

```cypher
MATCH (c:User {type:'customer'})-[b:BOUGHT]->()
WITH c, sum(b.count) as totalPurchases
RETURN 
    CASE 
        WHEN totalPurchases <= 2 THEN 'low'
        WHEN totalPurchases <= 5 THEN 'medium' 
        ELSE 'high'
    END as segment,
    count(c) as customers
ORDER BY segment;
```

### 9.5 Рекомендации "купили также"

```cypher
-- Для пользователя 1 найти товары, которые покупали другие, купившие те же товары
MATCH (u:User {userId: 1})-[:BOUGHT]->(p:Product)<-[:BOUGHT]-(other:User)
WITH DISTINCT other
MATCH (other)-[:BOUGHT]->(recommend:Product)
WHERE NOT (u:User {userId: 1})-[:BOUGHT]->(recommend)
RETURN recommend.name, count(*) as times
ORDER BY times DESC
LIMIT 5;
```

### 9.6 Поиск кратчайшего пути

```cypher
-- Найти связь между двумя пользователями
MATCH (a:User {userId: 1}), (b:User {userId: 100})
MATCH path = shortestPath((a)-[*..5]-(b))
RETURN path;
```

---

## Уровень 10: MERGE и обновление

### 10.1 MERGE - создание если нет

```cypher
MERGE (u:User {userId: 999})
SET u.name = 'Новый пользователь', u.type = 'customer'
RETURN u;
```

### 10.2 MERGE со связью

```cypher
MATCH (u:User {userId: 1})
MATCH (p:Product {productId: 50})
MERGE (u)-[:BOUGHT]->(p)
SET p = {count: 1};
```

### 10.3 ON CREATE SET / ON MATCH SET

```cypher
MERGE (u:User {userId: 100})
ON CREATE SET u.created = timestamp()
ON MATCH SET u.updated = timestamp()
RETURN u;
```

### 10.4 DETACH DELETE - удаление с связями

```cypher
MATCH (u:User {userId: 999})
DETACH DELETE u;
```

---

## Уровень 11: Практические примеры для marketplace

### 11.1 Статистика по базе

```cypher
MATCH (u:User) RETURN 'Всего пользователей', count(*)
UNION ALL MATCH (p:Product) RETURN 'Всего товаров', count(*)
UNION ALL MATCH (c:Category) RETURN 'Всего категорий', count(*)
UNION ALL MATCH ()-[r:BOUGHT]->() RETURN 'Всего заказов', count(*)
UNION ALL MATCH ()-[r:REVIEWED]->() RETURN 'Всего отзывов', count(*);
```

### 11.2 Топ-10 популярных товаров

```cypher
MATCH (u:User)-[b:BOUGHT]->(p:Product)
RETURN p.name, count(distinct u) as buyers, sum(b.count) as total
ORDER BY total DESC
LIMIT 10;
```

### 11.3 Топ-10 активных покупателей

```cypher
MATCH (c:User {type:'customer'})-[b:BOUGHT]->(p:Product)
RETURN c.name, sum(b.count) as orders, count(distinct p) as uniqueProducts
ORDER BY orders DESC
LIMIT 10;
```

### 11.4 Топ-10 продавцов

```cypher
MATCH (m:User {type:'merchant'})<-[:SOLD_BY]-(p:Product)<-[b:BOUGHT]-()
RETURN m.name, count(distinct p) as products, sum(b.count) as sold
ORDER BY sold DESC
LIMIT 10;
```

### 11.5 Рейтинг категорий

```cypher
MATCH (c:Category)<-[:IN_CATEGORY]-(p:Product)<-[r:REVIEWED]-()
RETURN c.name, avg(r.rating) as avgRating, count(r) as reviews
ORDER BY avgRating DESC;
```

### 11.6 Неактивные покупатели

```cypher
MATCH (c:User {type:'customer'})
WHERE NOT (c)-[:BOUGHT]->()
RETURN c.name;
```

### 11.7 Товары без продавца

```cypher
MATCH (p:Product)
WHERE NOT (p)-[:SOLD_BY]->()
RETURN p.name;
```

### 11.8交叉-продажи (cross-sell)

```cypher
-- Найти категории, которые покупают вместе с категорией "Электроника"
MATCH (c1:Category {name:'Электроника'})<-[:IN_CATEGORY]-(p1:Product)<-[:BOUGHT]-(u:User)-[:BOUGHT]->(p2:Product)-[:IN_CATEGORY]-(c2:Category)
WHERE c1 <> c2
RETURN c2.name, count(distinct u) as coPurchases
ORDER BY coPurchases DESC
LIMIT 10;
```

---

## Полезные функции

### Математические

```cypher
RETURN abs(-5), round(3.7), sqrt(16), log(10);
```

### Строковые

```cypher
RETURN toUpper('hello'), toLower('HELLO'), trim(' hello ');
RETURN split('a,b,c', ',');
RETURN replace('hello', 'l', 'r');
```

### Даты

```cypher
RETURN date(), datetime(), timestamp();
```

### Коллекции

```cypher
RETURN size([1,2,3]);  -- длина
RETURN [1,2,3][0];     -- элемент по индексу
RETURN [1,2,3][0..2];  -- срез
```

---

## Подключение

### Через cypher-shell

```bash
docker exec -it marketplace-neo4j cypher-shell -u neo4j -p 12345678
```

### Через браузер

http://localhost:7474
- Логин: `neo4j`
- Пароль: `12345678`

---

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия
- [02_graph_model.md](02_graph_model.md) - Модель графа
- [03_queries.md](03_queries.md) - Основные запросы
- [04_migration.md](04_migration.md) - Миграция из PostgreSQL