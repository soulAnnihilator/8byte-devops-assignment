output "cluster_name" {
  value = aws_ecs_cluster.ninja.name
}

output "service_name" {
  value = aws_ecs_service.ninja.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.ninja.arn
}

output "alb_arn_suffix" {
  value = aws_lb.ninja.arn_suffix
}

output "alb_dns_name" {
  value = aws_lb.ninja.dns_name
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.ninja.arn_suffix
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.ninja.name
}
