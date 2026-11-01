output "topic_arns" {
  value = { for k, v in aws_sns_topic.this : k => v.arn }
}

output "topic_names" {
  value = { for k, v in aws_sns_topic.this : k => v.name }
}
