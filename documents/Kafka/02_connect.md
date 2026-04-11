# Kafka - Паттерн Outbox

## Введение

Паттерн Outbox решает проблему надёжной отправки событий. Вместо отправки напрямую, события записываются в специальную таблицу (outbox), откуда Kafka Connect читает их и публикует в топик.

## Проблема

При традиционном подходе:
1. Записать данные в таблицу orders
2. Отправить событие в Kafka

Если шаг 2 не выполнится - возникнет несогласованность.

## Решение: Outbox Pattern

```
HTTP Request
     │
     ▼
┌────────────┐     ┌─────────────────┐
│ Transaction│────▶│  orders table    │
│           │     └─────────────────┘
│  1. Insert│
│  2. Insert│     ┌─────────────────┐
│   into    │────▶│  event_outbox   │
│  outbox   │     └─────────────────┘
└────────────┘              │
                           ▼
                   ┌─────────────────┐
                   │  Kafka Connect  │
                   │  JDBC Source  │
                   └─────────────────┘
                           │
                           ▼
                   ┌─────────────────┐
                   │  Kafka Topic    │
                   └─────────────────┘
```

## Таблица event_outbox

```sql
CREATE TABLE event_outbox (
    id          BIGSERIAL PRIMARY KEY,
    event_type  VARCHAR(128) NOT NULL,
    entity_id   VARCHAR(256) NOT NULL,
    payload    JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## Producer

### Python

```python
import psycopg2
import json
from kafka import KafkaProducer

conn = psycopg2.connect("postgresql://kafka:kafka@postgres-kafka:5432/kafkalab")

def create_order(order_data):
    cursor = conn.cursor()
    
    # Транзакция
    cursor.execute("BEGIN")
    try:
        # 1. Создать заказ
        cursor.execute("""
            INSERT INTO orders (user_id, amount) 
            VALUES (%s, %s) 
            RETURNING id
        """, (order_data['user_id'], order_data['amount']))
        order_id = cursor.fetchone()[0]
        
        # 2. Записать в outbox
        cursor.execute("""
            INSERT INTO event_outbox (event_type, entity_id, payload)
            VALUES ('order_created', %s, %s)
        """, (order_id, json.dumps({
            'order_id': order_id,
            'user_id': order_data['user_id'],
            'amount': order_data['amount']
        })))
        
        cursor.execute("COMMIT")
    except:
        cursor.execute("ROLLBACK")
        raise
```

## Kafka Connect JDBC Source

```json
{
  "name": "jdbc-source-outbox",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector",
    "tasks.max": "1",
    "connection.url": "jdbc:postgresql://postgres-kafka:5432/kafkalab",
    "connection.user": "kafka",
    "connection.password": "kafka",
    "table.whitelist": "event_outbox",
    "mode": "incrementing",
    "incrementing.column.name": "id",
    "topic.prefix": "db.",
    "poll.interval.ms": "2000",
    "errors.tolerance": "all",
    "errors.log.enable": "true"
  }
}
```

### Настройка

| Параметр | Значение | Описание |
|----------|----------|----------|
| table.whitelist | event_outbox | Таблица-источник |
| mode | incrementing | Режим инкремента |
| incrementing.column.name | id | Колонка для отслеживания |
| topic.prefix | db. | Префикс топика |

## Kafka Connect REST API

### Регистрация коннектора

```bash
curl -X POST -H "Content-Type: application/json" \
    --data @connect/jdbc-source-outbox.json \
    http://localhost:8083/connectors/
```

### Статус

```bash
curl http://localhost:8083/connectors/jdbc-source-outbox/status
```

### Удаление

```bash
curl -X DELETE http://localhost:8083/connectors/jdbc-source-outbox
```

## Потребление событий

### Consumer

```python
from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    'db.event_outbox',
    bootstrap_servers='localhost:9094',
    group_id='order-processor',
    value_deserializer=lambda m: json.loads(m.decode('utf-8'))
)

for message in consumer:
    event = message.value
    
    if event['event_type'] == 'order_created':
        process_order_created(event['payload'])
    
    elif event['event_type'] == 'order_updated':
        process_order_updated(event['payload'])
```

## Очистка outbox

```sql
-- После успешной обработки
DELETE FROM event_outbox WHERE id < (SELECT MAX(id) - 100 FROM event_outbox);
```

## Мониторинг

###lag коннектора

```bash
curl http://localhost:8083/connectors/jdbc-source-outbox/status | jq '.tasks[].offset'
```

### Количество событий

```sql
SELECT COUNT(*) FROM event_outbox;
```

## Преимущества

1. **Надёжность** - события не теряются
2. **Exactly-once** - можно достичь
3. **Асинхронность** - не блокирует HTTP
4. **CDC** - автоматический захват

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия