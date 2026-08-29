output "vpc_id" {
  value = aws_vpc.ninja.id
}

output "vpc_cidr" {
  value = aws_vpc.ninja.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  value = aws_subnet.database[*].id
}
