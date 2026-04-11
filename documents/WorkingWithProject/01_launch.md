# Работа с проектом - Запуск

## Требования

- Docker
- Docker Compose

## Запуск всех сервисов

```bash
docker-compose up -d
```

### Проверка статуса

```bash
docker-compose ps
```

### Логи

```bash
# Все сервисы
docker-compose logs -f

# Конкретный сервис
docker-compose logs -f postgres
docker-compose logs -f mongodb
docker-compose logs -f api
```

## Запуск отдельных сервисов

```bash
# Только PostgreSQL
docker-compose up -d postgres postgres_subscriber

# PostgreSQL + MongoDB + Redis
docker-compose up -d postgres mongodb redis

# API
docker-compose up -d api
```

## Остановка

```bash
# Остановить все
docker-compose down

# Остановить с данными
docker-compose down -v

# Остановить конкретный
docker-compose stop postgres
```

## Перезапуск

```bash
docker-compose restart postgres
```

## Подключение к сервисам

### PostgreSQL

```bash
# Primary
docker exec -it marketplace-db psql -U admin -d marketplace

# Subscriber
docker exec -it marketplace-subscriber psql -U admin -d marketplace
```

### MongoDB

```bash
docker exec -it marketplace-mongodb mongosh -u admin -p 123 --authenticationDatabase admin
```

### Redis

```bash
docker exec -it marketplace-redis redis-cli
```

### Neo4j

```bash
docker exec -it marketplace-neo4j cypher-shell -u neo4j -p 12345678
```

## Проблемы

### Контейнер не запускается

```bash
docker-compose logs <service>
docker inspect <container>
```

### Networking

```bash
docker network ls
docker network inspect <network>
```

## Смотрите также

- [02_testing.md](02_testing.md) - Тестирование
- [03_development.md](03_development.md) - Разработка