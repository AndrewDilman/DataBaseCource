# Работа с проектом - Тестирование

## Проверка сервисов

### PostgreSQL

```bash
# Подключение
docker exec -it marketplace-db psql -U admin -d marketplace -c "SELECT 1"

# Таблицы
docker exec -it marketplace-db psql -U admin -d marketplace -c "\dt"

# Статистика
docker exec -it marketplace-db psql -U admin -d marketplace -c "SELECT count(*) FROM users"
```

### MongoDB

```bash
# Подключение
docker exec -it marketplace-mongodb mongosh -u admin -p 123 --authenticationDatabase admin --eval "db.adminCommand('ping')"

# Коллекции
docker exec -it marketplace-mongodb mongosh -u admin -p 123 --authenticationDatabase admin --eval "db.getCollectionNames()"

# Документы
docker exec -it marketplace-mongodb mongosh -u admin -p 123 --authenticationDatabase admin --eval "db.products.countDocuments()"
```

### Redis

```bash
# Ping
docker exec -it marketplace-redis redis-cli PING

# Ключи
docker exec -it marketplace-redis redis-cli KEYS "*"
```

### Neo4j

```bash
# Подключение
docker exec -it marketplace-neo4j cypher-shell -u neo4j -p 12345678 "RETURN 1"

# Узлы
docker exec -it marketplace-neo4j cypher-shell -u neo4j -p 12345678 "MATCH (n) RETURN count(n)"
```

## API тесты

### Health check

```bash
curl http://localhost:4000/health
```

### Products API

```bash
# Список
curl http://localhost:4000/api/products

# По категории
curl "http://localhost:4000/api/products?category_id=1"

# Товар
curl http://localhost:4000/api/products/1
```

### Reports

```bash
curl http://localhost:4000/api/report/top-by-categories
```

## Репликация

### Проверка репликации

```bash
# На primary
docker exec marketplace-db psql -U admin -d marketplace -c "SELECT count(*) FROM goods"

# На subscriber (должно быть равно)
docker exec marketplace-subscriber psql -U admin -d marketplace -c "SELECT count(*) FROM goods"
```

## Тестовые данные

### Заполнение PostgreSQL

```bash
docker exec -i marketplace-db psql -U admin -d marketplace < seed_data.sql
```

### Очистка PostgreSQL

```bash
docker exec -i marketplace-db psql -U admin -d marketplace < crud_operations.sql
```

## Смотрите также

- [01_launch.md](01_launch.md) - Запуск
- [03_development.md](03_development.md) - Разработка