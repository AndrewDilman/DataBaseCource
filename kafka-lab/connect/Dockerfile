FROM confluentinc/cp-kafka-connect:7.6.1

USER root
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:10.7.4

# JDBC-драйвер PostgreSQL — кладём в lib каталога коннектора
RUN mkdir -p /tmp/pgjdbc
ADD --chmod=444 https://jdbc.postgresql.org/download/postgresql-42.7.4.jar \
    /tmp/pgjdbc/postgresql-42.7.4.jar
RUN JDBC_LIB="$(find /usr/share/confluent-hub-components -type d -path '*/lib' 2>/dev/null | grep -i jdbc | head -1)" && \
    if [ -n "$JDBC_LIB" ]; then cp /tmp/pgjdbc/postgresql-42.7.4.jar "$JDBC_LIB/"; fi

USER appuser
