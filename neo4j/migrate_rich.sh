#!/bin/bash
set -e
echo "=== PostgreSQL -> Neo4j Migration ==="
docker exec marketplace-db pg_isready -U admin || exit 1
docker exec marketplace-neo4j cypher-shell -u neo4j -p 12345678 "RETURN 1" || exit 1
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 "MATCH (n) DETACH DELETE n;"
docker exec marketplace-db mkdir -p /tmp/neo4j_export
docker exec marketplace-db psql -U admin -d marketplace -c "\copy customers TO STDOUT WITH CSV HEADER" > /dev/null 2>&1 || echo "skip"
docker exec marketplace-db psql -U admin -d marketplace -c "SET client_min_messages TO ERROR; \copy (SELECT user_id, name, user_type FROM users WHERE user_type = 'customer') TO '/tmp/neo4j_export/customers.csv' WITH CSV HEADER;"
docker cp marketplace-db:/tmp/neo4j_export/customers.csv /tmp/
docker cp /tmp/customers.csv marketplace-neo4j:/var/lib/neo4j/import/
docker exec -i marketplace-neo4j cypher-shell -u neo4j -p 12345678 -file /docker-entrypoint-initdb.d/01-init.cypher
echo "Done"
