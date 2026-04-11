# Monitoring - Grafana

## Введение

Grafana используется для визуализации метрик из Prometheus.

## Доступ

- URL: http://localhost:3000
- Логин: admin
- Пароль: admin

## Дашборды

### PostgreSQL Dashboard

Ключевые панели:
- Active connections
- Queries per second
- Transaction rate
- Database size

### MongoDB Dashboard

Ключевые панели:
- Connection pool
- Operation counters
- Memory usage

### Redis Dashboard

Ключевые панели:
- Used memory
- Commands processed
- Keyspace

## Настройка

### Добавление Data Source

1. Configuration → Data Sources
2. Add data source
3. Prometheus
4. URL: http://prometheus:9090

## Смотрите также

- [01_prometheus.md](01_prometheus.md) - Prometheus