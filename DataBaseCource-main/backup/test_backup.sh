#!/bin/bash

# Тестовый скрипт для проверки функциональности резервного копирования

echo "=== Тестирование системы резервного копирования ==="

# Установка тестовых переменных
export PGHOST=localhost
export PGPORT=5432
export POSTGRES_DB=marketplace
export PGUSER=admin
export PGPASSWORD=123
export CRON_MODE=once

echo "Запуск резервного копирования..."
cd /home/an/ВУЗ/7 семестр/базы данных/project/backup
bash backup.sh

echo "Проверка созданных файлов резервной копии..."
ls -la *.gz 2>/dev/null || echo "Нет сжатых файлов в текущей директории"

# Если запускается в контейнере, проверим в /backups
if [ -d "/backups" ]; then
    echo "Файлы резервной копии в /backups:"
    ls -la /backups/
fi

echo "=== Тестирование завершено ==="
