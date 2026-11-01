"""
Orders worker — SQS-triggered (orders queue), the "Worker Lambda" leg of
the reference flow: Client -> API Gateway -> Lambda -> SQS -> Worker
Lambda -> DynamoDB.

Each SQS record is a routed EventBridge domain event (OrderCreated /
OrderUpdated / OrderCancelled). A message that raises here is retried up
to the queue's redrive policy maxReceiveCount and then lands in the
orders DLQ for inspection/replay — never silently dropped.
"""
import json
import os

import boto3

dynamodb = boto3.resource("dynamodb")
ORDERS_TABLE = os.environ["ORDERS_TABLE_NAME"]


def handler(event, context):
    table = dynamodb.Table(ORDERS_TABLE)
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
    # EventBridge -> SQS envelopes the original event; unwrap defensively.
    detail = detail.get("detail", detail)

    order_id = detail["order_id"]
    table.update_item(
        Key={"order_id": order_id},
        UpdateExpression="SET #status = :status",
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={":status": "PROCESSED"},
    )
