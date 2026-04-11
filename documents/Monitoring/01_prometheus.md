# Monitoring - Prometheus

## Введение

Prometheus собирает метрики со всех компонентов проекта.

## Конфигурация

### prometheus.yml

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'mongodb-exporter'
    static_configs:
      - targets: ['mongodb-exporter:9216']
```

## Метрики PostgreSQL

### postgres-exporter

```yaml
postgres-exporter:
  image: prometheuscommunity/postgres-exporter:v0.15.0
  environment:
    DATA_SOURCE_NAME: "postgresql://admin:123@postgres:5432/marketplace?sslmode=disable"
```

### Ключевые метрики

| Метрика | Описание |
|---------|----------|
| pg_stat_database_tup_inserted | Вставлено строк |
| pg_stat_database_tup_updated | Обновлено строк |
| pg_stat_database_tup_deleted | Удалено строк |
| pg_stat_database_connections | Активные соединения |
| pg_stat_activity_count | Активные запросы |

## Метрики MongoDB

### mongodb-exporter

```yaml
mongodb-exporter:
  image: percona/mongodb_exporter:0.40
  environment:
    MONGODB_URI: "mongodb://admin:123@mongodb:27017/?authSource=admin"
```

### Ключевые метрики

| Метрика | Описание |
|--------|----------|
| mongodb_mmapv1_memory | Использование памяти |
| mongodb_connections_current | Активные соединения |
| mongodb_op_counters | Счётчики операций |

## Запросы PromQL

### Количество соединений PostgreSQL

```promql
pg_stat_database_connections{dbname="marketplace"}
```

### RPS (запросов в секунду)

```promql
rate(pg_stat_statements_executions[1m])
```

### Размер БД

```promql
pg_database_size_bytes / 1024 / 1024 / 1024
```

## Docker Compose

```yaml
prometheus:
  image: prom/prometheus:v2.40.0
  ports:
    - "9090:9090"
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml

grafana:
  image: grafana/grafana-enterprise
  ports:
    - "3000:3000"
```

## Доступ

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)

## Смотрите также

- [02_grafana.md](02_grafana.md) - Grafana