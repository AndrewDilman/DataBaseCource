"""
Продюсер: FastStream (Kafka) + HTTP для JMeter.
Ключ сообщения: entityId (bytes). Формат — единый JSON-конверт BusinessEvent.
"""

from __future__ import annotations

import os
import random
from contextlib import asynccontextmanager

from fastapi import FastAPI
from faststream.kafka import KafkaBroker

from event_model import EventType, random_event

KAFKA = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "localhost:9094")
TOPIC = os.environ.get("EVENTS_TOPIC", "business.events")

broker = KafkaBroker(KAFKA)
to_business_events = broker.publisher(TOPIC)


@asynccontextmanager
async def lifespan(app: FastAPI):
    await broker.start()
    yield
    await broker.close()


app = FastAPI(title="Kafka lab producer", lifespan=lifespan)

EVENT_TYPES: list[EventType] = [
    "OrderCreated",
    "OrderPaid",
    "OrderCancelled",
    "TrainingBooked",
    "TripCreated",
    "BookIssued",
]


async def publish_one(source: str = "faststream-shop") -> dict:
    et = random.choice(EVENT_TYPES)
    ev = random_event(et, source=source)
    key = ev.entity_id.encode("utf-8")
    # FastStream: публикация с ключом партиции (entityId)
    await to_business_events.publish(ev.to_json_dict(), key=key)
    return ev.to_json_dict()


@app.post("/publish/one")
async def http_publish_one():
    """Одиночное событие (удобно для отладки)."""
    data = await publish_one()
    return {"ok": True, "event": data}


@app.post("/publish/burst")
async def http_burst(count: int = 100):
    """
    Пакетная публикация для JMeter: POST /publish/burst?count=500
    """
    published = []
    for _ in range(max(1, min(count, 50_000))):
        published.append(await publish_one(source="jmeter-load"))
    return {"ok": True, "count": len(published)}


@app.get("/health")
async def health():
    return {"status": "ok", "kafka": KAFKA, "topic": TOPIC}
