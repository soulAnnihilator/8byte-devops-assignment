resource "aws_db_subnet_group" "ninja" {
  name       = "rds-${var.name}-db"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.name}-db"
  }
}

resource "aws_db_instance" "ninja" {
  identifier = "rds-${var.name}-postgres"

  engine         = "postgres"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "appdb"
  username = "appadmin"

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.ninja.name
  vpc_security_group_ids = [var.security_group_id]

  publicly_accessible = false
  multi_az            = var.multi_az

  backup_retention_period = var.backup_retention_period

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  apply_immediately   = true

  tags = {
    Name = "${var.name}-postgres"
  }
}
