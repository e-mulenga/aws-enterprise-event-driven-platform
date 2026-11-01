output "ai_router_lambda_arn" {
  value = aws_lambda_function.ai_event_router.arn
}

output "ai_audit_prefix" {
  value = "event-platform/ai-router/"
}
