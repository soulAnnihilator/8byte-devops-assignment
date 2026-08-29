output "alb_url" {
  value = "http://${module.ecs.alb_dns_name}"
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "platform_dashboard" {
  value = module.monitoring.platform_dashboard_name
}

output "application_dashboard" {
  value = module.monitoring.application_dashboard_name
}
