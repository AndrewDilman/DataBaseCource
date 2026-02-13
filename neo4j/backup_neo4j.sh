#!/bin/bash
set -e

echo "=== Резервное копирование Neo4j ==="

BACKUP_DIR="/backups/neo4j"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="neo4j_backup_$DATE"

# Создаем директорию для бэкапов, если она не существует
mkdir -p $BACKUP_DIR

# Ожидаем, пока Neo4j станет доступен
echo "Ожидание Neo4j..."
until docker exec marketplace-neo4j cypher-shell -u neo4j -p 12345678 "RETURN 1;" > /dev/null 2>&1; do
  echo "Neo4j недоступен, ждем 5 секунд..."
  sleep 5
done

echo "Neo4j доступен, начинаем резервное копирование..."

# Создаем резервную копию с помощью neo4j-admin
docker exec marketplace-neo4j bash -c "
  neo4j-admin database dump neo4j \
  --to-path=/tmp \
  --verbose
" > /dev/null 2>&1

# Архивируем бэкап
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" -C /tmp neo4j.dump

echo "Резервная копия сохранена: $BACKUP_DIR/$BACKUP_NAME.tar.gz"

# Удаляем старые бэкапы (оставляем последние 5)
cd $BACKUP_DIR
ls -t *.tar.gz | tail -n +6 | xargs rm -f

echo "Резервное копирование завершено!"