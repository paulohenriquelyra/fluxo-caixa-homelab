output "cluster_endpoint" {
  description = "O endpoint de conexão para o writer (leitura/escrita) do cluster Aurora."
  value       = aws_rds_cluster.aurora_cluster.endpoint
}

output "cluster_reader_endpoint" {
  description = "O endpoint de conexão para os readers (somente leitura) do cluster Aurora."
  value       = aws_rds_cluster.aurora_cluster.reader_endpoint
}

output "cluster_port" {
  description = "A porta do cluster Aurora."
  value       = aws_rds_cluster.aurora_cluster.port
}

output "master_password_secret_arn" {
  description = "O ARN do segredo no Secrets Manager que armazena a senha mestre."
  value       = aws_secretsmanager_secret.aurora_master_password.arn
}

output "security_group_id" {
  description = "O ID do Security Group associado ao cluster Aurora."
  value       = aws_security_group.aurora_sg.id
}

