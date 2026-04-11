# Kafka - Базовые понятия

## Введение

Apache Kafka - это распределённая платформа потоковой обработки событий. Используется для построения pipelines в реальном времени, передачи сообщений, аналитики.

## Основные понятия

### Топик (Topic)

Топик - это именованный канал сообщений:

```bash
# Создать топик
kafka-topics.sh --create --topic my-topic --bootstrap-server localhost:9092

# Список топиков
kafka-topics.sh --list --bootstrap-server localhost:9092
```

### Сообщение (Message)

Сообщение содержит ключ и значение:

```json
{
    "key": "user-123",
    "value": {
        "event": "user_registered",
        "data": { ... }
    }
}
```

### Партиция (Partition)

Топик делится на партиции для параллелизма:

```
Topic: orders
  ├── Partition 0
  ├── Partition 1
  └── Partition 2
```

### Брокер (Broker)

Брокер - это сервер Kafka:

```yaml
kafka:
  image: bitnami/kafka:3.7
  ports:
    - "9094:9092"
```

## Архитектура в проекте

### kafka-lab

```
kafka-lab/
├── docker-compose.yml    # Kafka cluster
├── sql/                  # PostgreSQL + таблицы
├── connect/              # Kafka Connect коннекторы
├── producer/             #Producer
├── consumer/             # Consumer
└── streams-app/          # Kafka Streams
```

## Компоненты kafka-lab

### Kafka (KRaft)

```yaml
kafka:
  image: docker.io/bitnami/kafka:3.7
  environment:
    KAFKA_CFG_NODE_ID: 0
    KAFKA_CFG_PROCESS_ROLES: controller,broker
    KAFKA_CFG_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093,EXTERNAL://:9094
```

### Schema Registry

```yaml
schema-registry:
  image: confluentinc/cp-schema-registry:7.6.1
  ports:
    - "8081:8081"
```

### Kafka Connect

```yaml
kafka-connect:
  build: ./connect
  ports:
    - "8083:8083"
```

### PostgreSQL

```yaml
postgres-kafka:
  image: postgres:15
  ports:
    - "5435:5432"
```

## Отправка сообщений

### Python producer

```python
from kafka import KafkaProducer
import json

producer = KafkaProducer(
    bootstrap_servers='localhost:9094',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

producer.send('business.events', {
    'event_type': 'order_created',
    'order_id': 123,
    'user_id': 456
})
```

### Отправка с ключом

```python
producer.send(
    'business.events',
    key='order-123'.encode(),
    value={'order_id': 123, 'amount': 1000}
)
```

## Потребление сообщений

### Python consumer

```python
from kafka import KafkaConsumer

consumer = KafkaConsumer(
    'business.events',
    bootstrap_servers='localhost:9094',
    group_id='my-group',
    value_deserializer=lambda m: json.loads(m.decode('utf-8'))
)

for message in consumer:
    print(message.value)
```

## Коннекторы Kafka Connect

### JDBC Source (чтение из БД)

```json
{
  "name": "jdbc-source-outbox",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector",
    "connection.url": "jdbc:postgresql://postgres-kafka:5432/kafkalab",
    "table.whitelist": "event_outbox",
    "mode": "incrementing",
    "incrementing.column.name": "id",
    "topic.prefix": "db."
  }
}
```

### JDBC Sink (запись в БД)

```json
{
  "name": "jdbc-sink-aggregates",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
    "connection.url": "jdbc:postgresql://postgres-kafka:5432/kafkalab",
    "topics": "business.events.aggregated",
    "table.name": "stream_aggregate_sink"
  }
}
```

## Паттерн Outbox

### Таблица outbox

```sql
CREATE TABLE event_outbox (
    id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(128) NOT NULL,
    entity_id VARCHAR(256) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Producer (вставка в outbox)

```python
# Заместо прямой записи
INSERT INTO orders (...) VALUES (...);

# Вставка в outbox
cursor.execute("""
    INSERT INTO event_outbox (event_type, entity_id, payload)
    VALUES ('order_created', %s, %s)
""", (order_id, json.dumps(order_data)))
```

### Kafka Connect (CDC)

```json
{
  "table.whitelist": "event_outbox",
  "topic.prefix": "db."
}
```

## Kafka Streams

### Приложение

```java
KStreamsBuilder builder = new KStreamsBuilder();

builder.stream("business.events")
    .groupBy((key, value) -> value.get("event_type"))
    .windowedBy(TimeWindows.of("window", 60000))
    .count("counts")
    .toStream()
    .to("business.events.aggregated");
```

## Проверка

### Топики

```bash
docker exec kafka-lab-kafka-1 kafka-topics.sh --list --bootstrap-server localhost:9092
```

### Сообщения

```bash
docker exec kafka-lab-kafka-1 kafka-console-consumer \
    --topic business.events \
    --from-beginning \
    --bootstrap-server localhost:9092
```

## Подключение

```bash
# Producer
docker exec -it kafka-lab-kafka-1 kafka-console-producer \
    --topic test \
    --bootstrap-server localhost:9092

# Consumer
docker exec -it kafka-lab-kafka-1 kafka-console-consumer \
    --topic test \
    --bootstrap-server localhost:9092
```

## Смотрите также

- [02_connect.md](02_connect.md) - Kafka Connect
- [03_outbox_pattern.md](03_outbox_pattern.md) - Паттерн Outbox