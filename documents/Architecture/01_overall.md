# Архитектура проекта

## Общая схема

```
                    Internet
                        │
                        ▼
┌─────────────────────────────────────────────┐
│              REST API (Node.js)              │
│              localhost:4000                 │
└─────────────────────┬───────────────────────┘
                      │
         ┌────────────┴────────────┐
         ▼                         ▼
┌────────────────┐       ┌────────────────┐
│    MongoDB     │       │     Redis      │
│  localhost:   │       │  localhost:    │
│    27017      │       │    6379        │
└────────────────┘       └────────────────┘
                               ▲
                               │
                    Cache (5 min TTL)

┌──────────────────────────────────────────────┐
│              PostgreSQL Primary              │
│              localhost:5433                 │
│                                              │
│  addresses, categories, users, goods,        │
│  orders, reviews, purchase_history           │
└──────────────────────┬───────────────────────┘
                       │ Logical Replication
                       ▼
┌──────────────────────────────────────────────┐
│           PostgreSQL Subscriber             │
│              localhost:5434                 │
│                                              │
│  Same tables (read replica)                  │
└──────────────────────────────────────────────┘
```

## Потоки данных

### 1. Запись товара (PostgreSQL → MongoDB)

```
User → API → PostgreSQL → migrate-products-to-mongo.sh → MongoDB
```

### 2. Чтение товаров (API → MongoDBRedis)

```
API → MongoDB → Redis cache (fallback)
```

### 3. Аналитика (Neo4j)

```
PostgreSQL → migrate.sh → Neo4j → Graph queries
```

### 4. События (Kafka)

```
App → PostgreSQL outbox → Kafka Connect → Kafka Topic
```

## Компоненты

### Docker Compose

| Сервис | Порт | Назначение |
|--------|------|-----------|
| postgres | 5433 | Primary БД |
| postgres_subscriber | 5434 | Read replica |
| mongodb | 27017 | Документы |
| redis | 6379 | Кэш |
| neo4j | 7474, 7687 | Граф |
| api | 4000 | REST API |
| prometheus | 9090 | Метрики |
| grafana | 3000 | Дашборды |

## Взаимодействие БД

### PostgreSQL

- Транзакционные данные
- Users, goods, orders
- Logical replication → subscriber

### MongoDB

- Каталог товаров
- Гибкая схема
- API reads

### Redis

- Кэш
- Cache-aside pattern
- TTL 5 min

### Neo4j

- Графовые связи
- Рекомендации
- Аналитика путей

## Надёжность

- PostgreSQL replica для read
- Redis cache для performance
- Prometheus monitoring

## Смотрите также

- [PostgreSQL/](../PostgreSQL/) - PostgreSQL
- [MongoDB/](../MongoDB/) - MongoDB
- [Redis/](../Redis/) - Redis
- [Neo4j/](../Neo4j/) - Neo4j