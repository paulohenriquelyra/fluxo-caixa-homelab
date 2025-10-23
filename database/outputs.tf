# ============================================
# Saídas do Projeto
# ============================================

output "aurora_cluster_endpoint" {
  description = "O endpoint do cluster Aurora PostgreSQL."
  value       = aws_rds_cluster.aurora_serverless.endpoint
}

output "aurora_cluster_master_password_secret_arn" {
  description = "O ARN do Secret no AWS Secrets Manager que armazena a senha mestre do Aurora."
  value       = aws_rds_cluster.aurora_serverless.master_user_secret[0].secret_arn
  sensitive   = true # Marcar como sensível para não exibir no console
}