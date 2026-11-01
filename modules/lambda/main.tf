# ============================================================
# modules/lambda
# ============================================================
# api_handler is the "Client -> API Gateway -> Lambda" leg; orders_worker
# and inventory_worker are the "SQS -> Worker Lambda -> DynamoDB" leg of
# the reference event flow. All three run in the Landing Zone's private
# subnets (never a VPC created here), use the shared least-privilege
# execution role from modules/security (with per-function inline policies
# attached here, since the table/queue/bus ARNs they need don't exist until
# this point in the graph), and are X-Ray traced.
# ============================================================

data "archive_file" "api_handler" {
  type        = "zip"
  source_file = "${path.module}/src/api_handler.py"
  output_path = "${path.module}/.build/api_handler.zip"
}

data "archive_file" "orders_worker" {
  type        = "zip"
  source_file = "${path.module}/src/orders_worker.py"
  output_path = "${path.module}/.build/orders_worker.zip"
}

data "archive_file" "inventory_worker" {
  type        = "zip"
  source_file = "${path.module}/src/inventory_worker.py"
  output_path = "${path.module}/.build/inventory_worker.zip"
}

resource "aws_cloudwatch_log_group" "api_handler" {
  name              = "/aws/lambda/${var.name_prefix}-api-handler"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "orders_worker" {
  name              = "/aws/lambda/${var.name_prefix}-orders-worker"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "inventory_worker" {
  name              = "/aws/lambda/${var.name_prefix}-inventory-worker"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_lambda_function" "api_handler" {
  function_name = "${var.name_prefix}-api-handler"
  role          = var.execution_role_arn
  handler       = "api_handler.handler"
  runtime       = "python3.12"
  timeout       = 10
  memory_size   = 256

  filename         = data.archive_file.api_handler.output_path
  source_code_hash = data.archive_file.api_handler.output_base64sha256

  kms_key_arn = var.kms_key_arn

  vpc_config {
    subnet_ids         = var.primary_vpc_private_subnet_ids
    security_group_ids = var.security_group_ids
  }

  dynamic "tracing_config" {
    for_each = var.enable_xray_tracing ? [1] : []
    content {
      mode = "Active"
    }
  }

  environment {
    variables = {
      ORDERS_TABLE_NAME = var.orders_table_name
      EVENT_BUS_NAME    = var.event_bus_name
    }
  }

  dead_letter_config {
    target_arn = var.dlq_arn
  }

  depends_on = [aws_cloudwatch_log_group.api_handler]

  tags = merge(var.tags, { Name = "${var.name_prefix}-api-handler" })
}

resource "aws_lambda_function" "orders_worker" {
  function_name = "${var.name_prefix}-orders-worker"
  role          = var.execution_role_arn
  handler       = "orders_worker.handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.orders_worker.output_path
  source_code_hash = data.archive_file.orders_worker.output_base64sha256

  kms_key_arn = var.kms_key_arn

  vpc_config {
    subnet_ids         = var.primary_vpc_private_subnet_ids
    security_group_ids = var.security_group_ids
  }

  dynamic "tracing_config" {
    for_each = var.enable_xray_tracing ? [1] : []
    content {
      mode = "Active"
    }
  }

  environment {
    variables = {
      ORDERS_TABLE_NAME = var.orders_table_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.orders_worker]

  tags = merge(var.tags, { Name = "${var.name_prefix}-orders-worker" })
}

resource "aws_lambda_function" "inventory_worker" {
  function_name = "${var.name_prefix}-inventory-worker"
  role          = var.execution_role_arn
  handler       = "inventory_worker.handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.inventory_worker.output_path
  source_code_hash = data.archive_file.inventory_worker.output_base64sha256

  kms_key_arn = var.kms_key_arn

  vpc_config {
    subnet_ids         = var.primary_vpc_private_subnet_ids
    security_group_ids = var.security_group_ids
  }

  dynamic "tracing_config" {
    for_each = var.enable_xray_tracing ? [1] : []
    content {
      mode = "Active"
    }
  }

  environment {
    variables = {
      EVENT_METADATA_TABLE_NAME = var.event_metadata_table_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.inventory_worker]

  tags = merge(var.tags, { Name = "${var.name_prefix}-inventory-worker" })
}

# ---- Event source mappings: SQS -> Worker Lambda ---------------------------
resource "aws_lambda_event_source_mapping" "orders_worker" {
  event_source_arn        = var.orders_queue_arn
  function_name           = aws_lambda_function.orders_worker.arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_lambda_event_source_mapping" "inventory_worker" {
  event_source_arn        = var.inventory_queue_arn
  function_name           = aws_lambda_function.inventory_worker.arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
}

# ---- Per-function least-privilege policies (attached here, not in
# modules/security, because the resource ARNs they scope to are only known
# at this point in the dependency graph) -------------------------------------
resource "aws_iam_role_policy" "api_handler" {
  name = "${var.name_prefix}-api-handler-policy"
  role = var.execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteOrders"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = var.orders_table_arn
      },
      {
        Sid      = "PublishDomainEvents"
        Effect   = "Allow"
        Action   = ["events:PutEvents"]
        Resource = var.event_bus_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "orders_worker" {
  name = "${var.name_prefix}-orders-worker-policy"
  role = var.execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "UpdateOrders"
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem"]
        Resource = var.orders_table_arn
      },
      {
        Sid    = "ConsumeOrdersQueue"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
        ]
        Resource = var.orders_queue_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "inventory_worker" {
  name = "${var.name_prefix}-inventory-worker-policy"
  role = var.execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteEventMetadata"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = "arn:aws:dynamodb:*:*:table/${var.event_metadata_table_name}"
      },
      {
        Sid    = "ConsumeInventoryQueue"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
        ]
        Resource = var.inventory_queue_arn
      }
    ]
  })
}
