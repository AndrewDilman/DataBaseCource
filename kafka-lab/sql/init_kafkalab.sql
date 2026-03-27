-- Таблицы для Kafka Connect: source (чтение) и sink (запись агрегатов)

CREATE TABLE IF NOT EXISTS event_outbox (
    id          BIGSERIAL PRIMARY KEY,
    event_type  VARCHAR(128) NOT NULL,
    entity_id   VARCHAR(256) NOT NULL,
    payload     JSONB NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stream_aggregate_sink (
    event_type   VARCHAR(128) NOT NULL,
    window_start BIGINT NOT NULL,
    window_end   BIGINT NOT NULL,
    event_count  BIGINT NOT NULL,
    ingested_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_type, window_start)
);

CREATE INDEX IF NOT EXISTS idx_outbox_id ON event_outbox (id);
