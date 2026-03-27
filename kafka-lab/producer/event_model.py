"""Единый контракт события (JSON). Поля: eventId, eventType, entityId, timestamp, source, payload, version, metadata."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any, Literal

from pydantic import BaseModel, Field


EventType = Literal[
    "OrderCreated",
    "OrderPaid",
    "OrderCancelled",
    "TrainingBooked",
    "SubscriptionExpired",
    "TripCreated",
    "CrashDetected",
    "BookIssued",
    "BookReturned",
]


class EventMetadata(BaseModel):
    correlation_id: str = Field(..., alias="correlationId")
    producer: str = Field(default="faststream-producer", alias="producer")
    schema_hint: str = Field(default="json+v1", alias="schemaHint")

    model_config = {"populate_by_name": True}


class BusinessEvent(BaseModel):
    event_id: str = Field(..., alias="eventId")
    event_type: str = Field(..., alias="eventType")
    entity_id: str = Field(..., alias="entityId")
    timestamp: str = Field(..., alias="timestamp")
    source: str = Field(..., alias="source")
    payload: dict[str, Any] = Field(default_factory=dict, alias="payload")
    version: str = Field(default="1.0", alias="version")
    metadata: EventMetadata = Field(..., alias="metadata")

    model_config = {"populate_by_name": True}

    def to_json_dict(self) -> dict[str, Any]:
        return self.model_dump(mode="json", by_alias=True)


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def random_event(
    event_type: EventType | None = None,
    *,
    source: str = "faststream-shop",
) -> BusinessEvent:
    et: EventType = event_type or "OrderCreated"
    eid = str(uuid.uuid4())
    correlation = str(uuid.uuid4())
    payloads: dict[str, dict[str, Any]] = {
        "OrderCreated": {"orderId": eid[:8], "amount": 99.5, "currency": "RUB"},
        "OrderPaid": {"orderId": eid[:8], "paymentId": str(uuid.uuid4())[:8]},
        "OrderCancelled": {"orderId": eid[:8], "reason": "user_request"},
        "TrainingBooked": {"slotId": str(uuid.uuid4())[:8], "coach": "ivan"},
        "SubscriptionExpired": {"memberId": eid[:8], "plan": "gold"},
        "TripCreated": {"routeId": "42", "vehicleId": "bus-7"},
        "CrashDetected": {"vehicleId": "bus-7", "severity": "high"},
        "BookIssued": {"isbn": "978-5-000", "readerId": eid[:8]},
        "BookReturned": {"isbn": "978-5-000", "readerId": eid[:8], "fineRub": 0},
    }
    return BusinessEvent(
        eventId=str(uuid.uuid4()),
        eventType=et,
        entityId=f"{et.lower()}-{eid[:8]}",
        timestamp=utc_now_iso(),
        source=source,
        payload=payloads.get(et, {}),
        version="1.0",
        metadata=EventMetadata(correlationId=correlation, producer="faststream-producer", schemaHint="json+v1"),
    )
