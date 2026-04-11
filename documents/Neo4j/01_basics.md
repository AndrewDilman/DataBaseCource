# Neo4j - Базовые понятия

## Введение

Neo4j - это графовая система управления базами данных. Данные хранятся как узлы (nodes) и связи (relationships) между ними, что идеально подходит для социальных сетей, рекомендаций, анализа связей.

## Основные понятия

### Узел (Node)

Узел - это сущность в графе:

```
(:User {name: "Иван"})
(:Product {name: "Смартфон"})
```

### Связь (Relationship)

Связь соединяет узлы:

```
(:User)-[:BOUGHT]->(:Product)
(:Product)-[:IN_CATEGORY]->(:Category)
```

### Метка (Label)

Метка - это тип узла:

```
CREATE (u:User)
CREATE (p:Product)
```

### Свойство (Property)

Свойства - это данные узла/связи:

```javascript
{
    name: "Иван",
    age: 30,
    email: "ivan@example.com"
}
```

## Типы данных

### Числа

- Integer (целое)
- Float (с плавающей точкой)

### Строки

- String (текст)

### Логические

- Boolean (true/false)

### Другие

- Point (геометрия)
- Date, DateTime, Time
- Duration
- Object (список)
- Map (словарь)

## Cypher - язык запросов

### CREATE - создание

```cypher
CREATE (u:User {name: "Иван", age: 30})
CREATE (u:User)-[:KNOWS]->(p:User {name: "Пётр"})
```

### MATCH - поиск

```cypher
MATCH (u:User) RETURN u
MATCH (u:User {name: "Иван"}) RETURN u
MATCH (u:User)-[:KNOWS]->(p) RETURN p
```

### WHERE - фильтрация

```cypher
MATCH (u:User)
WHERE u.age > 25
RETURN u
```

### RETURN - возврат

```cypher
MATCH (u:User)
RETURN u.name, u.age
```

### ORDER BY - сортировка

```cypher
MATCH (u:User)
RETURN u.name, u.age
ORDER BY u.age DESC
```

### LIMIT - ограничение

```cypher
MATCH (u:User)
RETURN u
LIMIT 10
```

### SKIP - пропуск

```cypher
MATCH (u:User)
RETURN u
SKIP 10 LIMIT 10
```

### SET - обновление свойств

```cypher
MATCH (u:User {name: "Иван"})
SET u.age = 31
SET u.name = NULL
```

### REMOVE - удаление свойств

```cypher
MATCH (u:User)
REMOVE u.age
```

### DELETE - удаление

```cypher
MATCH (u:User)
DETACH DELETE u
```

### MERGE - создание или обновление

```cypher
MERGE (u:User {name: "Иван"})
ON CREATE SET u.created = timestamp()
ON MATCH SET u.updated = timestamp()
```

## OPTIONAL MATCH

```cypher
MATCH (u:User)
OPTIONAL MATCH (u)-[:BOUGHT]->(p)
RETURN u.name, p
```

## Агрегации

```cypher
MATCH (u:User)-[:BOUGHT]->(p)
RETURN u.name, count(p) as purchases
ORDER BY purchases DESC
```

### COUNT, SUM, AVG, MIN, MAX

```cypher
MATCH (u:User)-[r:RATED]->(p:Product)
RETURN avg(r.rating) as avgRating
```

## WITH

Аналог WITH в SQL для передачи данных между частями запроса:

```cypher
MATCH (u:User)
WITH u, u.age as userAge
WHERE userAge > 25
RETURN u.name
```

## Индексы

```cypher
CREATE INDEX FOR (u:User) ON (u.name)
CREATE INDEX FOR (u:User) ON (u.age)
CREATE INDEX FOR (p:Product) ON (p.productId)
```

### Уникальные индексы

```cypher
CREATE CONSTRAINT FOR (u:User) REQUIRE u.userId IS UNIQUE
```

## Запросы с несколькими MATCH

```cypher
MATCH (u:User)
MATCH (p:Product)
WHERE (u)-[:BOUGHT]->(p)
RETURN u.name, p.name
```

## Подключение

### Через cypher-shell

```bash
docker exec marketplace-neo4j cypher-shell -u neo4j -p 12345678
```

### Через HTTP

```bash
curl -u neo4j:12345678 http://localhost:7474/db/data
```

## Функции

### Строки

```cypher
RETURN toUpper('hello')
RETURN toLower('HELLO')
RETURN substring('hello', 1, 3)
RETURN size('hello')
```

### Математика

```cypher
RETURN abs(-5)
RETURN round(3.7)
RETURN sqrt(16)
```

### Даты

```cypher
RETURN timestamp()
RETURN date()
RETURN datetime()
```

## Смотрите также

- [02_graph_model.md](02_graph_model.md) - Модель графа
- [03_queries.md](03_queries.md) - Запросы
- [04_migration.md](04_migration.md) - Миграция