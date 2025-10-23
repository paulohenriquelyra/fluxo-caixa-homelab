output "vpc_id" {
  description = "O ID da VPC criada."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Lista de IDs das sub-redes públicas."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Lista de IDs das sub-redes privadas."
  value       = aws_subnet.private[*].id
}

output "rds_monitoring_role_arn" {
  description = "ARN da IAM Role para o RDS Enhanced Monitoring."
  value       = aws_iam_role.rds_monitoring_role.arn
}
