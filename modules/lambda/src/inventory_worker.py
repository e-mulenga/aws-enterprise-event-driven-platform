"""
Inventory worker — SQS-triggered (inventory queue). Records an audit entry
in the event_metadata table for every inventory domain event it receives
(InventoryReserved / InventoryReleased / InventoryAdjusted), satisfying
the Event Auditing requirement independent of the EventBridge archive.
"""
import json
import os
import time

import boto3

dynamodb = boto3.resource("dynamodb")
EVENT_METADATA_TABLE = os.environ["EVENT_METADATA_TABLE_NAME"]


def handler(event, context):
    table = dynamodb.Table(EVENT_METADATA_TABLE)
    failures = []

    for record in event.get("Records", []):
        try:
            _process(record, table)
        except Exception as exc:  # noqa: BLE001 - reported via batchItemFailures
            failures.append({"itemIdentifier": record["messageId"]})
            print(f"Failed to process {record.get('messageId')}: {exc}")

    return {"batchItemFailures": failures}


def _process(record, table):
    detail = json.loads(record["body"])
    detail = detail.get("detail", detail)

    table.put_item(
        Item={
            "event_id": record["messageId"],
            "event_timestamp": str(int(time.time())),
            "event_type": "inventory",
            "payload": json.dumps(detail),
        }
    )
