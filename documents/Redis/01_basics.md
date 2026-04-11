# Redis - Базовые понятия

## Введение

Redis (Remote Dictionary Server) - это хранилище данных в памяти с открытым исходным кодом. Используется как кэш, session storage, message broker.

## Ключевые характеристики

- **In-memory** - данные хранятся в памяти
- **NoSQL** - key-value хранилище
- **Persistence** - опционально сохраняет на диск
- **Pub/Sub** - публикация/подписка на сообщения
- **Transactions** - атомарные операции
- **Lua** - серверные скрипты

## Типы данных

### 1. String (строка)

```bash
SET key value
GET key
INCR counter
DECR counter
APPEND key value
STRLEN key
```

### 2. List (список)

```bash
LPUSH key value    # добавить в начало
RPUSH key value   # добавить в конец
LPOP key         # получить с начала
RPOP key         # получить с конца
LRANGE key 0 -1 # получить все
```

### 3. Set (множество)

```bash
SADD key member     # добавить
SREM key member    # удалить
SMEMBERS key       # все элементы
SISMEMBER key member  # проверить
SUNION key1 key2   # объединение
```

### 4. Sorted Set (упорядоченное множество)

```bash
ZADD key score member   # добавить с score
ZRANGE key 0 -1        # получить по возрастанию
ZREVRANGE key 0 -1     # по убыванию
ZRANK key member       # позиция
```

### 5. Hash (хэш)

```bash
HSET key field value    # установить
HGET key field         # получить
HGETALL key           # все поля
HINCRBY key field 1    # инкремент
HDEL key field        # удалить
```

### 6. HyperLogLog

```bash
PFADD key element
PFCOUNT key
```

### 7. Bitmap

```bash
SETBIT key offset value
GETBIT key offset
BITCOUNT key
```

## Основные команды

### Управление ключами

```bash
KEYS pattern        # поиск по паттерну (*, ?, [])
EXISTS key          # проверить существование
DEL key            # удалить
EXPIRE key seconds # установить TTL
TTL key            # получить TTL
PERSIST key        # удалить TTL
RENAME key newkey  # переименовать
TYPE key          # тип значения
```

### Кэширование

```bash
SETEX key seconds value  # установить с TTL
PSETEX key ms value     # установить с TTL в мс
SETNX key value         # установить если нет
```

### Информация

```bash
INFO          # информация о сервере
INFO memory   # информация о памяти
CONFIG GET * # текущая конфигурация
```

## Команды сервера

```bash
PING          # проверить соединение
SELECT db    # переключить БД (0-15)
FLUSHDB      # очистить текущую БД
FLUSHALL     # очистить все БД
SHUTDOWN     # остановить сервер
```

## Конвейер (Pipelining)

```bash
# Отправить несколько команд за один запрос
(echo -e "SET key1 val1\nGET key1\nSET key2 val2\nGET key2\n") | nc localhost 6379
```

## Транзакции

```bash
MULTI      # н��чать транзакцию
SET key value
GET key
EXEC      # выполнить
DISCARD   # отменить
```

### WATCH (optimistic locking)

```bash
WATCH key
MULTI
SET key newvalue
EXEC      # если key изменилась - ошибка
```

## Pub/Sub

### Подписаться

```bash
SUBSCRIBE channel
PSUBSCRIBE pattern*
```

### Публиковать

```bash
PUBLISH channel message
```

## Lua скрипты

```bash
EVAL "return redis.call('GET', KEYS[1])" 1 key
```

## Настройка в проекте

### Docker Compose

```yaml
redis:
  image: redis:7-alpine
  container_name: marketplace-redis
  ports:
    - "6379:6379"
  volumes:
    - redis_data:/data
  command: redis-server --appendonly yes
```

### Опции

- `--appendonly yes` - persistence AOF
- `--save 60 1` - сохранять каждые 60 сек если 1 изменение

## Подключение

### CLI

```bash
# Через Docker
docker exec -it marketplace-redis redis-cli

# Напрямую
redis-cli -h localhost -p 6379
```

### Node.js (ioredis)

```javascript
const Redis = require('ioredis');
const redis = new Redis({
    host: 'localhost',
    port: 6379,
    password: '',
    db: 0
});
```

## Мониторинг

### MONITOR - в реальном времени

```bash
redis-cli MONITOR
```

### SLOWLOG - медленные команды

```bash
SLOWLOG GET
SLOWLOG RESET
```

## Производительность

- Операции O(1) для основных команд
- ~100k операций/сек
- Миллисекундная задержка

## Подробнее

See [02_caching_patterns.md](02_caching_patterns.md) for caching patterns used in the project.

## Смотрите также

- [02_caching_patterns.md](02_caching_patterns.md) - Паттерны кэширования