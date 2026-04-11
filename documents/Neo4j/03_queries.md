# Neo4j - Примеры запросов

## Основные запросы

### Найти всех пользователей

```cypher
MATCH (u:User) RETURN u
```

### Найти пользователя по ID

```cypher
MATCH (u:User {userId: 1}) RETURN u
```

### Найти всех продавцов

```cypher
MATCH (u:User) WHERE u.type = 'merchant' RETURN u
```

### Найти всех покупателей

```cypher
MATCH (u:User) WHERE u.type = 'customer' RETURN u
```

### Найти товары продавца

```cypher
MATCH (p:Product)-[:SOLD_BY]->(u:User {userId: 1})
RETURN p
```

### Найти категорию товара

```cypher
MATCH (p:Product {productId: 1})-[:IN_CATEGORY]->(c)
RETURN c
```

## Аналитика покупок

### Что купил пользователь

```cypher
MATCH (u:User {userId: 6})-[b:BOUGHT]->(p)
RETURN p.name, b.count
ORDER BY b.count DESC
```

### Кто купил товар

```cypher
MATCH (u:User)-[b:BOUGHT]->(p:Product {productId: 1})
RETURN u.name, b.count
```

### Топ покупателей

```cypher
MATCH (u:User)-[b:BOUGHT]->()
RETURN u.name, sum(b.count) as total
ORDER BY total DESC
LIMIT 10
```

### Популярные товары

```cypher
MATCH (u:User)-[b:BOUGHT]->(p)
RETURN p.name, count(*) as buyers, sum(b.count) as total
ORDER BY total DESC
LIMIT 10
```

## Отзывы

### Отзывы о товаре

```cypher
MATCH (u:User)-[r:REVIEWED]->(p:Product {productId: 1})
RETURN u.name, r.rating, r.comment
ORDER BY r.rating DESC
```

### Средний рейтинг товара

```cypher
MATCH (u:User)-[r:REVIEWED]->(p:Product {productId: 1})
RETURN avg(r.rating) as avgRating, count(r) as reviewCount
```

### Топ по рейтингу

```cypher
MATCH (u:User)-[r:REVIEWED]->(p)
RETURN p.name, avg(r.rating) as avgRating, count(r) as reviews
ORDER BY avgRating DESC
LIMIT 10
```

## Категории

### Товары по категориям

```cypher
MATCH (p:Product)-[:IN_CATEGORY]->(c)
RETURN c.name, count(p) as productCount
ORDER BY productCount DESC
```

### Продавцы по категориям

```cypher
MATCH (p:Product)-[:IN_CATEGORY]->(c), (p)-[:SOLD_BY]->(u)
RETURN c.name, u.name, count(p) as productCount
```

## Рекомендации

### Товары, купленные вместе с данным

```cypher
MATCH (u:User)-[b1:BOUGHT]->(p1:Product {productId: 1})
MATCH (u)-[b2:BOUGHT]->(p2)
WHERE p2 <> p1
RETURN p2, sum(b2.count) as coPurchaseCount
ORDER BY coPurchaseCount DESC
LIMIT 5
```

### Пользователи, купившие тот же товар

```cypher
MATCH (p:Product {productId: 1})<-[b:BOUGHT]-(u)
MATCH (u)-[b2:BOUGHT]->(other)
WHERE other <> p
RETURN other, sum(b2.count) as count
ORDER BY count DESC
```

## Пути

### Короткий путь между пользователями

```cypher
MATCH path = shortestPath(
    (u1:User {userId: 6})-[:BOUGHT*1..3]-(u2:User {userId: 10})
)
RETURN path
```

### Все пути

```cypher
MATCH path = (u1:User {userId: 6})-[:BOUGHT*1..2]-(u2:User)
RETURN path
```

## Агрегации

### Количество пользователей по типам

```cypher
MATCH (u:User)
RETURN u.type, count(u)
```

### Количество товаров по категориям

```cypher
MATCH (p:Product)-[:IN_CATEGORY]->(c)
RETURN c.name, count(p)
```

## Удаление

### Удалить связь

```cypher
MATCH (u:User)-[r:BOUGHT]->(p)
WHERE u.userId = 6 AND p.productId = 1
DELETE r
```

### Удалить узел и связи

```cypher
MATCH (u:User {userId: 100})
DETACH DELETE u
```

## Обновление

### Обновить свойство

```cypher
MATCH (u:User {userId: 6})
SET u.name = 'Новое имя'
```

### Добавить свойство

```cypher
MATCH (u:User {userId: 6})
SET u.email = 'ivan@example.com'
```

## Транзакции

```cypher
BEGIN
MATCH (u:User {userId: 6})
SET u.age = 31
MATCH (p:Product {productId: 1})<-[:BOUGHT]-(u)
SET u.lastPurchase = timestamp()
COMMIT
```

## Подключение

```bash
docker exec marketplace-neo4j cypher-shell -u neo4j -p 12345678
```

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия
- [02_graph_model.md](02_graph_model.md) - Модель графа
- [04_migration.md](04_migration.md) - Миграция