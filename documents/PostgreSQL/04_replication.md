# PostgreSQL - Логическая репликация

## Введение

Логическая репликация в PostgreSQL позволяет копировать данные на уровне отдельных таблиц или всей базы данных между серверами. В отличие от физической репликации, логическая работает на уровне DML операций (INSERT, UPDATE, DELETE).

## Концепции

### Публикация (Publication)

Публикация - это набор таблиц, изменения которых будут реплицироваться. Создаётся на издателе (primary).

### Подписка (Subscription)

Подписка определяет подключение к публикации на другом сервере. Создаётся на подписчике (replica).

## Настройка в проекте

### Архитектура

```
marketplace-db (primary)          marketplace-subscriber (replica)
┌─────────────────┐            ┌─────────────────┐
│ PostgreSQL 15   │───log───▶│ PostgreSQL 15   │
│                 │ logical  │                 │
│ Публикация:    │ repl.    │ Подписка:       │
│ marketplace_    │          │ marketplace_    │
│ all_tables     │          │ all_tables_sub │
└─────────────────┘          └─────────────────┘
```

### Настройка primary (издатель)

В docker-compose.yml:

```yaml
postgres:
  image: postgres:15
  command: ["postgres",
            "-c", "wal_level=logical",
            "-c", "max_wal_senders=10",
            "-c", "max_replication_slots=10"]
```

### Создание публикации

```sql
-- Создание публикации всех таблиц
CREATE PUBLICATION marketplace_all_tables FOR TABLE 
    addresses, 
    categories, 
    users, 
    goods, 
    orders, 
    reviews, 
    purchase_history, 
    pickup_points, 
    warehouses;

-- Или для всех таблиц
CREATE PUBLICATION marketplace_all_tables FOR ALL TABLES;
```

### Создание подписки

```sql
CREATE SUBSCRIPTION marketplace_all_tables_sub
CONNECTION 'host=postgres port=5432 dbname=marketplace user=admin password=123'
PUBLICATION marketplace_all_tables
WITH (
    copy_data = true,
    create_slot = true,
    enabled = true
);
```

## Управление репликацией

### Проверить статус подписки

```sql
-- На подписчике
SELECT 
    subname,
    subenabled,
    subslotname,
    subpublications
FROM pg_subscription;
```

### Включить/выключить подписку

```sql
-- Выключить
ALTER SUBSCRIPTION marketplace_all_tables_sub DISABLE;

-- Включить
ALTER SUBSCRIPTION marketplace_all_tables_sub ENABLE;
```

### Удалить подписку

```sql
DROP SUBSCRIPTION IF EXISTS marketplace_all_tables_sub;
```

### Проверить статус слотов

```sql
-- На издателе
SELECT * FROM pg_replication_slots;
```

###lag (задержка репликации)

```sql
-- На подписчике
SELECT 
    slot_name,
    plugin,
    restart_lsn,
    confirmed_lsn,
    (restart_lsn - confirmed_lsn) / 1024 / 1024 as lag_mb
FROM pg_replication_slots;
```

## Скрипты в проекте

### setup_replication.sh

```bash
#!/bin/bash
# Скрипт настройки репликации

echo "Ожидание запуска основной базы данных..."
sleep 60

# Проверка готовности primary
docker exec marketplace-db pg_isready -U admin

# Создание подписки
docker exec marketplace-subscriber psql -U admin -d marketplace -c "
    DO \$\$
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM pg_subscription 
            WHERE subname = 'marketplace_all_tables_sub'
        ) THEN
            CREATE SUBSCRIPTION marketplace_all_tables_sub
            CONNECTION 'host=postgres port=5432 dbname=marketplace user=admin password=123'
            PUBLICATION marketplace_all_tables
            WITH (
                copy_data = true,
                create_slot = true,
                enabled = true
            );
            RAISE NOTICE 'Подписка успешно создана';
        END IF;
    END
    \$\$;
"
```

### sub_create_subscription.sql

```sql
-- Заглушка для подписки
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_subscription WHERE subname = 'marketplace_all_tables_sub') THEN
        EXECUTE 'DROP SUBSCRIPTION IF EXISTS marketplace_all_tables_sub';
    END IF;
END $$;
```

## Мониторинг репликации

### Статистика WAL

```sql
SELECT 
    pid,
    usesysid,
    usename,
    application_name,
    client_addr,
    backend_start,
    state,
    sync_priority,
    sync_state
FROM pg_stat_replication;
```

### Задержка

```sql
SELECT 
    extract(epoch from (now() - replay_lag)) as lag_seconds
FROM pg_stat_replication
LIMIT 1;
```

### Статус репликации

```sql
SELECT 
    status,
    write_lsn,
    flush_lsn,
    replay_lsn,
    write_lsn - replay_lsn as diff
FROM pg_stat_replication;
```

## Устранение проблем

### Подписка не создаётся

1. Проверить что wal_level = logical:
   ```sql
   SHOW wal_level;
   ```

2. Проверить max_wal_senders:
   ```sql
   SHOW max_wal_senders;
   ```

3. Проверить max_replication_slots:
   ```sql
   SHOW max_replication_slots;
   ```

### Репликация отстаёт

1. Проверить нагрузку на primary
2. Увеличить max_wal_senders
3. Оптимизировать индексы

### Конфликты репликации

Пример конфликта:
```
ERROR: could not serialize-due to конфликт with conflicting serializable transaction
```

Решение:
1. Настроить snapshot synchronization
2. Использовать `ALTER SUBSCRIPTION ... WITH (synchronous_commit = true);`

## Использование в приложении

### Чтение с реплики

```javascript
// Подключение к реплике для чтения
const replicaConfig = {
    host: 'localhost',
    port: 5434,
    database: 'marketplace',
    user: 'admin',
    password: '123'
};
```

### Переключение при отказе

```javascript
async function getConnection() {
    try {
        return await connect(primaryConfig);
    } catch (e) {
        return await connect(replicaConfig);
    }
}
```

## Резервное копирование реплики

```bash
# Остановить репликацию
docker exec marketplace-subscriber psql -U admin -d marketplace -c "ALTER SUBSCRIPTION marketplace_all_tables_sub DISABLE;

# Создать дамп
docker exec marketplace-subscriber pg_dump -U admin marketplace > backup.sql

# Восстановить при необходимо��ти
cat backup.sql | docker exec -i marketplace-subscriber psql -U admin marketplace
```

## Подключение

```bash
# К primary
psql -h localhost -p 5433 -U admin -d marketplace

# К реплике
psql -h localhost -p 5434 -U admin -d marketplace
```

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия
- [02_schema_in_project.md](02_schema_in_project.md) - Схема БД
- [03_operations.md](03_operations.md) - Операции с данными
- [06_backup.md](06_backup.md) - Резервное копирование