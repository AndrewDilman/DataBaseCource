# Neo4j - Модель графа в проекте

## Обзор

В проекте используется Neo4j для анализа связей между:
- Пользователями (покупатели и продавцы)
- Товарами
- Категориями
- Заказами и отзывами

## Модель данных

### Узлы (Nodes)

#### User (Пользователь)

```
(u:User {
    userId: 1,
    name: "ТехноМир",
    type: "merchant"
})
```

| Свойство | Тип | Описание |
|----------|-----|----------|
| userId | Integer | ID пользователя |
| name | String | Имя |
| type | String | 'customer' или 'merchant' |

#### Product (Товар)

```
(p:Product {
    productId: 1,
    name: "Смартфон Samsung",
    merchantId: 1,
    categoryId: 1
})
```

| Свойство | Тип | Описание |
|----------|-----|----------|
| productId | Integer | ID товара |
| name | String | Название |
| merchantId | Integer | ID продавца |
| categoryId | Integer | ID категории |

#### Category (Категория)

```
(c:Category {
    categoryId: 1,
    name: "Электроника"
})
```

| Свойство | Тип | Описание |
|----------|-----|----------|
| categoryId | Integer | ID категории |
| name | String | Название |

### Связи (Relationships)

#### SOLD_BY (продаёт)

```
(p:Product)-[:SOLD_BY]->(u:User)
```

Связь от товара к продавцу.

#### IN_CATEGORY (в категории)

```
(p:Product)-[:IN_CATEGORY]->(c:Category)
```

Связь от товара к категории.

#### BOUGHT (купил)

```
(u:User)-[b:BOUGHT]->(p:Product)
```

| Свойство | Тип | Описание |
|----------|-----|----------|
| count | Integer | Количество покупок |

Связь от покупателя к товару.

#### REVIEWED (оставил отзыв)

```
(u:User)-[r:REVIEWED]->(p:Product)
```

| Свойство | Тип | Описание |
|----------|-----|----------|
| rating | Integer | Рейтинг (1-5) |
| comment | String | Текст отзыва |

Связь от покупателя к товару с отзывом.

## Визуализация

```
         ┌──────────────┐
         │   User     │
         │ (merchant) │
         └─────┬──────┘
               │
        ┌──────▼─────┐
        │  SOLD_BY   │
        └──────┬─────┘
              │
      ┌──────▼──────┐
      │  Product   │
      └─────┬──────┘
            │
     ┌─────┴──────┐
     │            │
┌────▼────┐ ┌───▼─────┐
│BOUGHT   │ │IN_CATEGORY
│         │ │         │
└────┬────┘ └───┬─────┘
     │          │
     │    ┌────▼────┐
     │    │Category │
     │    └─────────┘
     │
     │    ┌─────────┐
     └───▶│ REVIEWED│
          └─────────┘
```

## Создание ограничений

Для обеспечения уникальности:

```cypher
CREATE CONSTRAINT FOR (u:User) REQUIRE u.userId IS UNIQUE
CREATE CONSTRAINT FOR (p:Product) REQUIRE p.productId IS UNIQUE
CREATE CONSTRAINT FOR (c:Category) REQUIRE c.categoryId IS UNIQUE
```

## Индексы

```cypher
CREATE INDEX FOR (u:User) ON (u.name)
CREATE INDEX FOR (p:Product) ON (p.name)
CREATE INDEX FOR (c:Category) ON (c.name)
```

## Примеры узлов

### Пользователь

```cypher
CREATE (u:User {userId: 1, name: 'ТехноМир', type: 'merchant'})
CREATE (u:User {userId: 6, name: 'Иван Иванов', type: 'customer'})
```

### Товар

```cypher
CREATE (p:Product {
    productId: 1,
    name: 'Смартфон Samsung Galaxy',
    merchantId: 1,
    categoryId: 1
})
```

### Категория

```cypher
CREATE (c:Category {categoryId: 1, name: 'Электроника'})
```

## Примеры связей

### SOLD_BY

```cypher
MATCH (p:Product {productId: 1})
MATCH (u:User {userId: 1})
MERGE (p)-[:SOLD_BY]->(u)
```

### IN_CATEGORY

```cypher
MATCH (p:Product {productId: 1})
MATCH (c:Category {categoryId: 1})
MERGE (p)-[:IN_CATEGORY]->(c)
```

### BOUGHT

```cypher
MATCH (u:User {userId: 6})
MATCH (p:Product {productId: 1})
MERGE (u)-[b:BOUGHT]->(p)
SET b.count = 2
```

### REVIEWED

```cypher
MATCH (u:User {userId: 6})
MATCH (p:Product {productId: 1})
MERGE (u)-[r:REVIEWED]->(p)
SET r.rating = 5, r.comment = 'Отличный товар!'
```

## Подключение

```bash
docker exec marketplace-neo4j cypher-shell -u neo4j -p 12345678
```

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия Cypher
- [03_queries.md](03_queries.md) - Примеры запросов
- [04_migration.md](04_migration.md) - Миграция из PostgreSQL