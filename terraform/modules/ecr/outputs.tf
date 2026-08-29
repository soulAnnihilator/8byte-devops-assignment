output "repository_name" {
  value = aws_ecr_repository.ninja.name
}

output "repository_url" {
  value = aws_ecr_repository.ninja.repository_url
}

output "repository_arn" {
  value = aws_ecr_repository.ninja.arn
}
