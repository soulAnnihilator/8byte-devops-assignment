variable "name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "alb_arn_suffix" {
  type = string
}

variable "target_group_arn_suffix" {
  type = string
}

variable "rds_instance_identifier" {
  type = string
}
