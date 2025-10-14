#!/usr/bin/env bash
set -euo pipefail

# Настройки
BACKUP_DIR="/backups"
PRIMARY_HOST="${PGHOST:-postgres}"
PRIMARY_PORT="${PGPORT:-5432}"
PRIMARY_DB="${POSTGRES_DB:-marketplace}"
PRIMARY_USER="${PGUSER:-admin}"
PRIMARY_PASSWORD="${PGPASSWORD:-123}"

DATA_DIR="/var/lib/postgresql/data" # монтируется read-only из primary

mkdir -p "$BACKUP_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

perform_backup() {
  TS=$(date '+%Y%m%d_%H%M%S')

  # Файлы дампов
  DB_DUMP_FILE="$BACKUP_DIR/${PRIMARY_DB}_${TS}.dump"
  GLOBALS_FILE="$BACKUP_DIR/globals_${TS}.sql"

  log "Начинаю дамп БД ${PRIMARY_DB} на ${PRIMARY_HOST}:${PRIMARY_PORT}"

  # 1) Логический дамп схемы и данных конкретной БД (формат Custom)
  PGPASSWORD="$PRIMARY_PASSWORD" pg_dump \
    -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$PRIMARY_USER" \
    -d "$PRIMARY_DB" -Fc -f "$DB_DUMP_FILE"

  # 2) Глобальные объекты (роли, tablespaces) — настройки уровня кластера
  PGPASSWORD="$PRIMARY_PASSWORD" pg_dumpall \
    -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$PRIMARY_USER" -g \
    > "$GLOBALS_FILE"

  # 3) Конфиги инстанса (если доступны через общий volume)
  if [ -r "$DATA_DIR/postgresql.conf" ]; then
    cp -f "$DATA_DIR/postgresql.conf" "$BACKUP_DIR/postgresql.conf_$TS"
  fi
  if [ -r "$DATA_DIR/pg_hba.conf" ]; then
    cp -f "$DATA_DIR/pg_hba.conf" "$BACKUP_DIR/pg_hba.conf_$TS"
  fi

  # 4) Сжатие текстовых артефактов
  gzip -f "$GLOBALS_FILE" || true
  gzip -f "$BACKUP_DIR/postgresql.conf_$TS" 2>/dev/null || true
  gzip -f "$BACKUP_DIR/pg_hba.conf_$TS" 2>/dev/null || true

  log "Готово: $(basename "$DB_DUMP_FILE"), $(basename "$GLOBALS_FILE").gz и конфиги (если были)"

  # 5) Retention: удаляем файлы старше 7 дней
  find "$BACKUP_DIR" -type f -mtime +7 -print -delete | sed 's/^/[cleanup] /' || true
}

# Если задан CRON_MODE=once — выполнить один раз и выйти (для ручного запуска)
if [ "${CRON_MODE:-loop}" = "once" ]; then
  perform_backup
  exit 0
fi

log "Сервис резервного копирования запущен. Интервал: 10 минут"
while true; do
  perform_backup
  sleep 600
done


