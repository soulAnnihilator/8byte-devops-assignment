locals {
  name = "${var.project_name}-${var.environment}"
}

module "vpc" {
  source = "../../modules/vpc"

  name = local.name

  vpc_cidr = var.vpc_cidr

  availability_zones = var.availability_zones

  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs

  single_nat_gateway = var.single_nat_gateway
}

module "security_groups" {
  source = "../../modules/security-groups"

  name = local.name

  vpc_id = module.vpc.vpc_id

  container_port = var.container_port
}

module "ecr" {
  source = "../../modules/ecr"

  name = local.name
}

module "rds" {
  source = "../../modules/rds"

  name = local.name

  subnet_ids = module.vpc.database_subnet_ids

  security_group_id = module.security_groups.rds_security_group_id

  instance_class     = var.rds_instance_class
  allocated_storage  = var.rds_allocated_storage
  multi_az           = var.rds_multi_az

  backup_retention_period = var.rds_backup_retention_period
  deletion_protection     = var.rds_deletion_protection
  skip_final_snapshot     = var.rds_skip_final_snapshot
}

module "ecs" {
  source = "../../modules/ecs"

  name = local.name

  aws_region = var.aws_region

  vpc_id = module.vpc.vpc_id

  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  alb_security_group_id = module.security_groups.alb_security_group_id
  ecs_security_group_id = module.security_groups.ecs_security_group_id

  container_image = "${module.ecr.repository_url}:bootstrap"

  container_port = var.container_port

  cpu    = var.ecs_cpu
  memory = var.ecs_memory

  desired_count = var.ecs_desired_count
  max_count     = var.ecs_max_count

  db_secret_arn = module.rds.master_user_secret_arn
}

module "monitoring" {
  source = "../../modules/monitoring"

  name = local.name

  aws_region = var.aws_region

  ecs_cluster_name       = module.ecs.cluster_name
  alb_arn_suffix         = module.ecs.alb_arn_suffix
  target_group_arn_suffix = module.ecs.target_group_arn_suffix

  rds_instance_identifier = module.rds.db_instance_identifier
}
