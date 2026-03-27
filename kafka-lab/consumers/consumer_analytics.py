"""
Consumer group: analytics-consumers
Автоматический commit (периодический). Обработка ошибок: повтор + DLQ.
Примечание: при auto.commit возможны повторные доставки — в проде нужна идемпотентность.
"""

from __future__ import annotations

import logging
import sys
import time
from collections import Counter

from confluent_kafka import Consumer, KafkaException, Producer

from common import BOOTSTRAP, DLQ_TOPIC, TOPIC, parse_event, validate_envelope

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("analytics")

MAX_RETRIES = 3
BACKOFF_SEC = 0.3
stats: Counter[str] = Counter()


def make_dlq_producer() -> Producer:
    return Producer({"bootstrap.servers": BOOTSTRAP, "client.id": "analytics-dlq-producer"})


def send_dlq(producer: Producer, raw: bytes | None, key: bytes | None, err: str) -> None:
    headers = [("error", err.encode("utf-8")), ("consumer", b"analytics-consumers")]
    producer.produce(DLQ_TOPIC, value=raw, key=key, headers=headers)
    producer.flush(timeout=10)


def process_message(data: dict) -> None:
    validate_envelope(data)
    et = str(data.get("eventType", ""))
    stats[et] += 1
    if sum(stats.values()) % 50 == 0:
        log.info("ANALYTICS totals (sample): %s", dict(stats.most_common(5)))


def main() -> None:
    consumer = Consumer(
        {
            "bootstrap.servers": BOOTSTRAP,
            "group.id": "analytics-consumers",
            "enable.auto.commit": True,
            "auto.commit.interval.ms": 3000,
            "auto.offset.reset": "earliest",
            "client.id": "analytics-consumer-1",
        }
    )
    dlq = make_dlq_producer()
    consumer.subscribe([TOPIC])
    log.info("Subscribed %s group=analytics-consumers auto commit", TOPIC)

    try:
        while True:
            msg = consumer.poll(timeout=1.0)
            if msg is None:
                continue
            if msg.error():
                raise KafkaException(msg.error())

            raw = msg.value()
            key = msg.key()
            attempt = 0
            while True:
                try:
                    data = parse_event(raw)
                    process_message(data)
                    break
                except Exception as e:
                    attempt += 1
                    if attempt >= MAX_RETRIES:
                        log.exception("ANALYTICS failed after retries, DLQ: %s", e)
                        send_dlq(dlq, raw, key, repr(e))
                        break
                    log.warning("ANALYTICS retry %s/%s: %s", attempt, MAX_RETRIES, e)
                    time.sleep(BACKOFF_SEC)
    except KeyboardInterrupt:
        log.info("Stopping, stats=%s", dict(stats))
    finally:
        consumer.close()


if __name__ == "__main__":
    main()
    sys.exit(0)
