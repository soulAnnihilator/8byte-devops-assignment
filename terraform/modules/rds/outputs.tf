output "db_instance_identifier" {
  value = aws_db_instance.ninja.id
}

output "db_address" {
  value = aws_db_instance.ninja.address
}

output "db_port" {
  value = aws_db_instance.ninja.port
}

output "master_user_secret_arn" {
  value     = aws_db_instance.ninja.master_user_secret[0].secret_arn
  sensitive = true
}
