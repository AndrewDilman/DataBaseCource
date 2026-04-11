# PostgreSQL - Резервное копирование

## Введение

Резервное копирование - это критически важная часть управления БД. PostgreSQL предоставляет несколько инструментов для создания резервных копий.

## Инструменты

### pg_dump

Утилита для создания логического дампа одной базы данных.

```bash
pg_dump -h localhost -p 5432 -U admin -d marketplace -Fc -f backup.dump
```

### pg_dumpall

Утилита для создания дампа всего кластера (все БД, роли, табличные пространства).

```bash
pg_dumpall -h localhost -p 5432 -U admin -g -f globals.sql
```

## Скрипт резервного копирования в проекте

### backup.sh

Проект использует автоматический скрипт резервного копирования:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Настройки
BACKUP_DIR="/backups"
PRIMARY_HOST="${PGHOST:-postgres}"
PRIMARY_PORT="${PGPORT:-5432}"
PRIMARY_DB="${POSTGRES_DB:-marketplace}"
PRIMARY_USER="${PGUSER:-admin}"
PRIMARY_PASSWORD="${PGPASSWORD:-123}"

perform_backup() {
    TS=$(date '+%Y%m%d_%H%M%S')
    
    # Дамп базы данных (формат Custom)
    PGPASSWORD="$PRIMARY_PASSWORD" pg_dump \
        -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$PRIMARY_USER" \
        -d "$PRIMARY_DB" -Fc -f "$BACKUP_DIR/${PRIMARY_DB}_${TS}.dump"
    
    # Глобальные объекты
    PGPASSWORD="$PRIMARY_PASSWORD" pg_dumpall \
        -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$PRIMARY_USER" -g \
        > "$BACKUP_DIR/globals_${TS}.sql"
    
    # Расширения
    PGPASSWORD="$PRIMARY_PASSWORD" psql \
        -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$PRIMARY_USER" \
        -d "$PRIMARY_DB" -c "\dx" > "$BACKUP_DIR/extensions_${TS}.sql"
    
    # Параметры БД
    PGPASSWORD="$PRIMARY_PASSWORD" psql \
        -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$PRIMARY_USER" \
        -d "$PRIMARY_DB" -c "SELECT name, setting FROM pg_settings;" \
        > "$BACKUP_DIR/db_settings_${TS}.sql"
    
    # Только схема
    PGPASSWORD="$PRIMARY_PASSWORD" pg_dump \
        -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$PRIMARY_USER" \
        -d "$PRIMARY_DB" --schema-only > "$BACKUP_DIR/schema_${TS}.sql"
    
    # Retention: удаляем файлы старше 7 дней
    find "$BACKUP_DIR" -type f -mtime +7 -delete
}
```

## Типы резервных копий

### 1. Логический дамп (pg_dump)

```bash
# Формат Custom (сжатый, рекомендуется)
pg_dump -Fc marketplace -f marketplace.dump

# Формат Plain (SQL текст)
pg_dump -Fp marketplace -f marketplace.sql

# Формат Directory (параллельный)
pg_dump -Fd marketplace -f backup_dir

# Только схема
pg_dump --schema-only marketplace -f schema.sql

# Только данные
pg_dump --data-only marketplace -f data.sql
```

### 2. Дамп всех БД

```bash
pg_dumpall -g > globals.sql
```

### 3. Физический дамп

```bash
# Остановка PostgreSQL
docker stop marketplace-db

# Копирование data directory
docker run --rm -v postgres_data:/data -v $(pwd)/backup:/backup alpine \
    tar czf /backup/pg_data.tar.gz /data
```

## Восстановление

### Восстановление из Custom дампа

```bash
pg_restore -h localhost -p 5432 -U admin -d marketplace -Fc backup.dump
```

### Восстановление из SQL дампа

```bash
psql -h localhost -p 5432 -U admin -d marketplace -f backup.sql
```

### Восстановление отдельных таблиц

```bash
pg_restore -h localhost -p 5432 -U admin -d marketplace -Fc backup.dump -t table_name
```

### Восстановление с новым именем

```sql
-- Создать БД
createdb -h localhost -U admin new_database

-- Восстановить
pg_restore -h localhost -U admin -d new_database backup.dump
```

## Автоматизация

### Docker Compose backup сервис

```yaml
backup:
    image: postgres:15
    volumes:
      - ./backup:/opt/backup:ro
      - backups_data:/backups
      - postgres_data:/var/lib/postgresql/data:ro
    entrypoint: ["bash", "-c", "sleep 90 && bash /opt/backup/backup.sh"]
    environment:
      PGHOST: postgres
      PGPORT: 5432
      PGUSER: admin
      PGPASSWORD: 123
      POSTGRES_DB: marketplace
      CRON_MODE: loop
```

### Cron

```bash
# Выполнять каждый день в 2:00
0 2 * * * /path/to/backup.sh

# Выполнять каждый час
0 * * * * /path/to/backup.sh
```

## Стратегии резервного копирования

### 1. Ежедневный полный дамп

```bash
# Ежедневно в 2:00
0 2 * * * pg_dump -Fc marketplace > /backups/daily_$(date +\%Y\%m\%d).dump
```

### 2. Инкрементальный (WAL ар��ив)

```bash
# Настроить архивирование WAL
wal_level = archive
archive_mode = on
archive_command = 'cp %p /wal_archive/%f'
```

### 3. Реплика + дамп

```
 Primary (запись) → Replica (чтение, дамп)
```

## Проверка резервной копии

### Проверить целостность

```bash
pg_restore --list backup.dump | head -20
```

### Тестовое восстановление

```bash
# Создать тестовую БД
createdb -h localhost test_restore

# Восстановить
pg_restore -h localhost -d test_restore backup.dump

# Проверить
psql -h localhost -d test_restore -c "\dt"
```

## Безопасность

### Пароли в резервных копиях

```bash
# Без пароля (используя .pgpass)
echo "localhost:5432:marketplace:admin:123" > ~/.pgpass
chmod 0600 ~/.pgpass

# С дампом пароля
pg_dump -h localhost -U admin marketplace -f backup.dump
```

### Шифрование

```bash
# GPG шифрование
gpg --symmetric --cipher-algo AES256 backup.dump
```

## Мониторинг

### Размер резервных копий

```bash
ls -lh /backups/
du -sh /backups/
```

### Дата последнего дампа

```bash
ls -lt /backups/ | head -1
```

## Подключение

```bash
# К primary
psql -h localhost -p 5433 -U admin -d marketplace
```

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия
- [04_replication.md](04_replication.md) - Репликация
- [WorkingWithProject/01_launch.md](../WorkingWithProject/01_launch.md) - Запуск проекта