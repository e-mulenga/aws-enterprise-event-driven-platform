output "table_names" {
  value = {
    customer_profiles = aws_dynamodb_table.customer_profiles.name
    orders            = aws_dynamodb_table.orders.name
    event_metadata    = aws_dynamodb_table.event_metadata.name
  }
}

output "table_arns" {
  value = {
    customer_profiles = aws_dynamodb_table.customer_profiles.arn
    orders            = aws_dynamodb_table.orders.arn
    event_metadata    = aws_dynamodb_table.event_metadata.arn
  }
}

output "stream_arns" {
  value = {
    customer_profiles = aws_dynamodb_table.customer_profiles.stream_arn
    orders            = aws_dynamodb_table.orders.stream_arn
    event_metadata    = aws_dynamodb_table.event_metadata.stream_arn
  }
}
