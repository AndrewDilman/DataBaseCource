# Работа с проектом - Разработка

## Подключение к БД

### PostgreSQL

```bash
# Primary
psql -h localhost -p 5433 -U admin -d marketplace

# Subscriber  
psql -h localhost -p 5434 -U admin -d marketplace
```

### MongoDB

```bash
mongosh "mongodb://admin:123@localhost:27017/marketplace?authSource=admin"
```

### Redis

```bash
redis-cli -h localhost -p 6379
```

### Neo4j

```bash
cypher-shell -u neo4j -p 12345678
```

## Логи

### Docker

```bash
# Все логи
docker-compose logs -f

# Конкретный сервис
docker-compose logs -f postgres
docker-compose logs -f mongodb
docker-compose logs -f api
```

### PostgreSQL

```bash
docker exec marketplace-db cat /var/log/postgresql/postgresql-*.log
```

## Отладка

### Сеть

```bash
# Проверить связь между контейнерами
docker exec marketplace-api ping postgres

# DNS
docker exec marketplace-api nslookup postgres
```

### Переменные окружения

```bash
docker exec marketplace-api env
```

##Разработка API

### Пересборка

```bash
docker-compose build api
docker-compose up -d api
```

### Логи API

```bash
docker-compose logs -f api
```

## Полезные команды

### Перезапуск сервиса

```bash
docker-compose restart api
```

### Вход в контейнер

```bash
docker exec -it marketplace-db bash
docker exec -it marketplace-mongodb bash
```

### Копирование файлов

```bash
docker cp container:/path/to/file ./local/path
docker cp ./local/file container:/path/to/file
```

##常见问题

### Большой размер БД

```bash
docker exec marketplace-db psql -U admin -d marketplace -c "SELECT pg_size_pretty(pg_database_size('marketplace'))"
```

### Медленные запросы

```bash
docker exec marketplace-db psql -U admin -d marketplace -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10"
```

### Нет подключения

1. Проверить что контейнер запущен
2. Проверить порты
3. Проверить firewall

## Смотрите также

- [01_launch.md](01_launch.md) - Запуск
- [02_testing.md](02_testing.md) - Тестирование