output "event_bus_name" {
  value = aws_cloudwatch_event_bus.this.name
}

output "event_bus_arn" {
  value = aws_cloudwatch_event_bus.this.arn
}

output "archive_name" {
  value = try(aws_cloudwatch_event_archive.this[0].name, null)
}

output "rule_arns" {
  value = {
    orders_domain_events    = aws_cloudwatch_event_rule.orders_domain_events.arn
    inventory_domain_events = aws_cloudwatch_event_rule.inventory_domain_events.arn
    business_events         = aws_cloudwatch_event_rule.business_events.arn
    integration_events      = aws_cloudwatch_event_rule.integration_events.arn
  }
}
