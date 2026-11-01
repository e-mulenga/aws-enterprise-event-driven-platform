output "api_id" {
  value = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.this.api_endpoint
}

output "custom_domain_name" {
  value = try(aws_apigatewayv2_domain_name.this[0].domain_name, null)
}
