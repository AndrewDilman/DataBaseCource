#!/bin/bash

until pg_isready -h postgres -p 5432; do
    echo "Ожидание запуска основного PostgreSQL..."
    sleep 2
done

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE SUBSCRIPTION db_sub
    CONNECTION 'host=postgres port=5432 dbname=marketplace user=replicator password=123'
    PUBLICATION db_pub;
EOSQL