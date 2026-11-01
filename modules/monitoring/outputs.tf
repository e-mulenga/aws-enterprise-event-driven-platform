output "dashboard_name" {
  value = aws_cloudwatch_dashboard.this.dashboard_name
}

output "grafana_workspace_id" {
  value = try(aws_grafana_workspace.this[0].id, null)
}
