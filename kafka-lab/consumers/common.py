"""Общие настройки Kafka для лабораторных консьюмеров."""

from __future__ import annotations

import json
import os
from typing import Any

BOOTSTRAP = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "localhost:9094")
TOPIC = os.environ.get("EVENTS_TOPIC", "business.events")
DLQ_TOPIC = os.environ.get("DLQ_TOPIC", "business.events.dlq")


def parse_event(value: bytes | None) -> dict[str, Any]:
    if not value:
        return {}
    return json.loads(value.decode("utf-8"))


def validate_envelope(data: dict[str, Any]) -> None:
    required = ("eventId", "eventType", "entityId", "timestamp", "source", "payload", "version", "metadata")
    missing = [k for k in required if k not in data]
    if missing:
        raise ValueError(f"invalid envelope, missing: {missing}")
