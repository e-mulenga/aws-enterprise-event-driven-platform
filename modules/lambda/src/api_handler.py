"""
API handler — fronted by API Gateway (HTTP API).

POST /orders  -> writes an order record, publishes an OrderCreated domain
event to the EventBridge custom bus, returns 201. This is the
"Client -> API Gateway -> Lambda" leg of the reference event flow; the
worker Lambdas (orders_worker / inventory_worker) pick up from the SQS
queues that the EventBridge rules fan the event out to.

Placeholder business logic: this is a portfolio-architecture repository,
not a production order-management system. The structure (input
validation, idempotency key, structured logging, X-Ray subsegments,
explicit error handling) is what a real handler would keep; the fields are
illustrative.
"""
import json
import os
import time
import uuid

import boto3

dynamodb = boto3.resource("dynamodb")
events = boto3.client("events")

ORDERS_TABLE = os.environ["ORDERS_TABLE_NAME"]
EVENT_BUS_NAME = os.environ["EVENT_BUS_NAME"]


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "invalid JSON body"})

    customer_id = body.get("customer_id")
    items = body.get("items")
    if not customer_id or not items:
        return _response(400, {"error": "customer_id and items are required"})

    order_id = str(uuid.uuid4())
    now = int(time.time())

    table = dynamodb.Table(ORDERS_TABLE)
    table.put_item(
        Item={
            "order_id": order_id,
            "customer_id": customer_id,
            "items": items,
            "status": "RECEIVED",
            "created_at": now,
        }
    )

    events.put_events(
        Entries=[
            {
                "Source": "shopsphere.orders",
                "DetailType": "OrderCreated",
                "EventBusName": EVENT_BUS_NAME,
                "Detail": json.dumps(
                    {"order_id": order_id, "customer_id": customer_id, "items": items}
                ),
            }
        ]
    )

    return _response(201, {"order_id": order_id, "status": "RECEIVED"})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
