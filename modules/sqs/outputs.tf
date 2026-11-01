output "queue_names" {
  value = { for k, v in aws_sqs_queue.this : k => v.name }
}

output "queue_urls" {
  value = { for k, v in aws_sqs_queue.this : k => v.url }
}

output "queue_arns" {
  value = { for k, v in aws_sqs_queue.this : k => v.arn }
}

output "dlq_names" {
  value = { for k, v in aws_sqs_queue.dlq : k => v.name }
}

output "dlq_urls" {
  value = { for k, v in aws_sqs_queue.dlq : k => v.url }
}

output "dlq_arns" {
  value = { for k, v in aws_sqs_queue.dlq : k => v.arn }
}
