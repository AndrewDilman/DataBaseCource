# Kafka-лаборатория (курс БД)

Реализует цепочку: **FastStream + JMeter → Kafka → консьюмеры (2 группы) → Kafka Streams → топик агрегатов → Kafka Connect ↔ PostgreSQL**. Отдельно лежат примеры **Avro** (`.avsc`) и **Protobuf** (`.proto`) для того же конверта событий.

## Состав

| Компонент | Описание |
|-----------|----------|
| `docker-compose.yml` | Kafka (KRaft), Schema Registry, Kafka Connect (JDBC), PostgreSQL `kafkalab`, Java Streams |
| `producer/` | FastAPI + **FastStream** Kafka, единый JSON-конверт, ключ = `entityId` |
| `consumers/` | `audit-consumers` (ручной commit), `analytics-consumers` (auto commit), retry + **DLQ** `business.events.dlq` |
| `streams-app/` | Трансформация JSON, **окно 1 мин**, **count** по `eventType` → `business.events.aggregated` |
| `connect/` | JDBC **Source** (`event_outbox` → `db.event_outbox`), JDBC **Sink** (агрегаты → `stream_aggregate_sink`) |
| `schemas/` | `BusinessEventEnvelope.avsc`, `business_event.proto` |
| `jmeter/kafka_lab_burst.jmx` | HTTP-нагрузка на `POST /publish/burst` |

## Минимальная структура события (JSON)

`eventId`, `eventType`, `entityId`, `timestamp`, `source`, `payload`, `version`, `metadata` (см. `producer/event_model.py`).

## Запуск

1. Поднять инфраструктуру (из каталога `kafka-lab`):

```bash
docker compose up -d --build
```

2. Дождаться healthy у Kafka, затем зарегистрировать коннекторы:

```powershell
.\scripts\register_connectors.ps1
```

3. Установить зависимости продюсера и консьюмеров:

```bash
cd producer && pip install -r requirements.txt
cd ../consumers && pip install -r requirements.txt
```

4. Запустить продюсер (с хоста, порт брокера **9094**):

```bash
set KAFKA_BOOTSTRAP_SERVERS=localhost:9094
cd producer
uvicorn main:app --host 0.0.0.0 --port 8000
```

5. В двух терминалах — консьюмеры:

```bash
set KAFKA_BOOTSTRAP_SERVERS=localhost:9094
python consumer_audit.py
python consumer_analytics.py
```

6. Генерация событий: `POST http://localhost:8000/publish/burst?count=200` или JMeter, открыв `jmeter/kafka_lab_burst.jmx`.

7. Проверка агрегатов в БД (после работы Streams + Sink):

```bash
docker exec -it kafka-lab-postgres psql -U kafka -d kafkalab -c "SELECT * FROM stream_aggregate_sink ORDER BY window_start DESC LIMIT 10;"
```

8. Демо JDBC Source: вставить строки в outbox и смотреть топик `db.event_outbox`:

```bash
docker exec -i kafka-lab-postgres psql -U kafka -d kafkalab < scripts/seed_outbox.sql
```

## Schema Registry (просмотр Avro)

После старта: UI/REST на `http://localhost:8081`. Для учебного просмотра достаточно файла `schemas/BusinessEventEnvelope.avsc`; регистрация схем в Registry для JSON-топика не обязательна.

## Топики

- `business.events` — основной поток
- `business.events.dlq` — ошибочные сообщения
- `business.events.aggregated` — выход Streams (и sink в БД)
- `db.event_outbox` — CDC-style чтение из `event_outbox`
