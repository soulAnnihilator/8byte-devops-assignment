output "platform_dashboard_name" {
  value = aws_cloudwatch_dashboard.platform.dashboard_name
}

output "application_dashboard_name" {
  value = aws_cloudwatch_dashboard.application.dashboard_name
}
