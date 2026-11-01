# ============================================================
# modules/api-gateway
# ============================================================
# HTTP API (API Gateway v2) — the REST-API event source and the entry
# point of the reference flow (Client -> API Gateway -> Lambda -> SQS ->
# Worker Lambda -> DynamoDB). HTTP APIs are chosen over REST APIs (v1) for
# this platform: ~70% lower cost per request and native JWT authorizer
# support, at the cost of giving up request/response transformation,
# usage plans and API keys — see docs/service-selection-rationale.md.
#
# The custom domain (optional, off by default to avoid a Route 53 record
# churn cost in every ephemeral dev stack) reuses the Landing Zone's
# existing hosted zone and wildcard ACM certificate; neither is created
# here.
# ============================================================

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "access_logs" {
  name              = "/aws/apigateway/${var.name_prefix}-api"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = var.throttle_burst_limit
    throttling_rate_limit  = var.throttle_rate_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access_logs.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  tags = var.tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 10000
}

resource "aws_apigatewayv2_route" "create_order" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /orders"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# ---- Optional custom domain, under the Landing Zone's existing zone -------
resource "aws_apigatewayv2_domain_name" "this" {
  count = var.enable_custom_domain ? 1 : 0

  domain_name = "api.${var.environment}.${var.domain_name}"

  domain_name_configuration {
    certificate_arn = var.acm_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = var.tags
}

resource "aws_apigatewayv2_api_mapping" "this" {
  count = var.enable_custom_domain ? 1 : 0

  api_id      = aws_apigatewayv2_api.this.id
  domain_name = aws_apigatewayv2_domain_name.this[0].id
  stage       = aws_apigatewayv2_stage.default.id
}

resource "aws_route53_record" "api" {
  count = var.enable_custom_domain ? 1 : 0

  zone_id = var.route53_zone_id
  name    = aws_apigatewayv2_domain_name.this[0].domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.this[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.this[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
