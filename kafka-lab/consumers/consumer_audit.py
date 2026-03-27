"""
Consumer group: audit-consumers
Ручной commit offset после успешной обработки.
Ошибки: до 3 повторов с задержкой, затем DLQ и commit (не блокируем партицию).
"""

from __future__ import annotations

import logging
import sys
import time

from confluent_kafka import Consumer, KafkaException, Producer

from common import BOOTSTRAP, DLQ_TOPIC, TOPIC, parse_event, validate_envelope

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("audit")

MAX_RETRIES = 3
BACKOFF_SEC = 0.5


def make_dlq_producer() -> Producer:
    return Producer({"bootstrap.servers": BOOTSTRAP, "client.id": "audit-dlq-producer"})


def send_dlq(producer: Producer, raw: bytes | None, key: bytes | None, err: str) -> None:
    headers = [("error", err.encode("utf-8")), ("consumer", b"audit-consumers")]
    producer.produce(DLQ_TOPIC, value=raw, key=key, headers=headers)
    producer.flush(timeout=10)


def process_message(data: dict) -> None:
    validate_envelope(data)
    log.info("AUDIT ok eventId=%s type=%s entity=%s", data.get("eventId"), data.get("eventType"), data.get("entityId"))


def main() -> None:
    consumer = Consumer(
        {
            "bootstrap.servers": BOOTSTRAP,
            "group.id": "audit-consumers",
            "enable.auto.commit": False,
            "auto.offset.reset": "earliest",
            "client.id": "audit-consumer-1",
        }
    )
    dlq = make_dlq_producer()
    consumer.subscribe([TOPIC])
    log.info("Subscribed %s group=audit-consumers manual commit", TOPIC)

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
                    consumer.commit(asynchronous=False)
                    break
                except Exception as e:
                    attempt += 1
                    if attempt >= MAX_RETRIES:
                        log.exception("AUDIT failed after retries, DLQ: %s", e)
                        send_dlq(dlq, raw, key, repr(e))
                        consumer.commit(asynchronous=False)
                        break
                    log.warning("AUDIT retry %s/%s: %s", attempt, MAX_RETRIES, e)
                    time.sleep(BACKOFF_SEC)
    except KeyboardInterrupt:
        log.info("Stopping")
    finally:
        consumer.close()


if __name__ == "__main__":
    main()
    sys.exit(0)
