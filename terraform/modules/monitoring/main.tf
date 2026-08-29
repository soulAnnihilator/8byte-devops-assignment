resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-5xx"
  alarm_description   = "ALB target 5xx responses"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.name}-rds-cpu"
  alarm_description   = "RDS CPU is high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_identifier
  }
}

resource "aws_cloudwatch_dashboard" "platform" {
  dashboard_name = "${var.name}-platform"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x = 0
        y = 0
        width = 12
        height = 6
        properties = {
          title = "ECS CPU / Memory"
          region = var.aws_region
          view = "timeSeries"
          stat = "Average"
          period = 300
          metrics = [
            ["ECS/ContainerInsights", "CpuUtilized", "ClusterName", var.ecs_cluster_name],
            [".", "MemoryUtilized", ".", var.ecs_cluster_name]
          ]
        }
      },
      {
        type = "metric"
        x = 12
        y = 0
        width = 12
        height = 6
        properties = {
          title = "ALB Requests / 5xx"
          region = var.aws_region
          view = "timeSeries"
          stat = "Sum"
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            [".", "HTTPCode_Target_5XX_Count", ".", var.alb_arn_suffix]
          ]
        }
      },
      {
        type = "metric"
        x = 0
        y = 6
        width = 12
        height = 6
        properties = {
          title = "Target Response Time"
          region = var.aws_region
          view = "timeSeries"
          stat = "Average"
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix]
          ]
        }
      },
      {
        type = "metric"
        x = 12
        y = 6
        width = 12
        height = 6
        properties = {
          title = "RDS CPU / Connections"
          region = var.aws_region
          view = "timeSeries"
          stat = "Average"
          period = 300
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_identifier],
            [".", "DatabaseConnections", ".", var.rds_instance_identifier]
          ]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "application" {
  dashboard_name = "${var.name}-application"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x = 0
        y = 0
        width = 12
        height = 6
        properties = {
          title = "Application Requests"
          region = var.aws_region
          view = "timeSeries"
          stat = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]
          ]
        }
      },
      {
        type = "metric"
        x = 12
        y = 0
        width = 12
        height = 6
        properties = {
          title = "HTTP Status Codes"
          region = var.aws_region
          view = "timeSeries"
          stat = "Sum"
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", var.alb_arn_suffix],
            [".", "HTTPCode_Target_4XX_Count", ".", var.alb_arn_suffix],
            [".", "HTTPCode_Target_5XX_Count", ".", var.alb_arn_suffix]
          ]
        }
      },
      {
        type = "metric"
        x = 0
        y = 6
        width = 12
        height = 6
        properties = {
          title = "Healthy Targets"
          region = var.aws_region
          view = "timeSeries"
          stat = "Average"
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix],
            [".", "UnHealthyHostCount", ".", var.target_group_arn_suffix, ".", var.alb_arn_suffix]
          ]
        }
      },
      {
        type = "metric"
        x = 12
        y = 6
        width = 12
        height = 6
        properties = {
          title = "RDS Free Storage"
          region = var.aws_region
          view = "timeSeries"
          stat = "Average"
          period = 300
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.rds_instance_identifier]
          ]
        }
      }
    ]
  })
}
