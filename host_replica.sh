#!/bin/bash

set -e

echo "host replication replicator 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf

echo "host $POSTGRES_DB replicator 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '123';
    CREATE PUBLICATION db_pub FOR ALL TABLES;
    GRANT CONNECT ON DATABASE "$POSTGRES_DB" TO replicator;
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO replicator;
    GRANT USAGE ON SCHEMA public TO replicator;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO replicator;

    -- Настраиваем автоматические права для всех будущих пользователей (если будут созданы новые пользователи)
    ALTER DEFAULT PRIVILEGES FOR USER "$POSTGRES_USER" IN SCHEMA public GRANT SELECT ON TABLES TO replicator;
    ALTER DEFAULT PRIVILEGES FOR USER "$POSTGRES_USER" IN SCHEMA public GRANT USAGE ON SEQUENCES TO replicator;
EOSQL

pg_ctl reload