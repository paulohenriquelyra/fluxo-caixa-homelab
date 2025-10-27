# ==============================================================================
# OUTPUTS DO MÓDULO RDS-SOURCE
# ==============================================================================

output "instance_endpoint" {
  value       = aws_db_instance.default.endpoint
  description = "Endpoint da instância RDS PostgreSQL (formato: hostname:porta). Use este endpoint para conectar ao banco de dados."
}

output "instance_address" {
  value       = aws_db_instance.default.address
  description = "Endereço (hostname) da instância RDS PostgreSQL, sem a porta."
}

output "instance_port" {
  value       = aws_db_instance.default.port
  description = "Porta da instância RDS PostgreSQL (padrão: 5432)."
}

output "instance_arn" {
  value       = aws_db_instance.default.arn
  description = "ARN (Amazon Resource Name) da instância RDS. Use para referências em políticas IAM ou tags."
}

output "instance_id" {
  value       = aws_db_instance.default.id
  description = "Identificador da instância RDS."
}

output "db_name" {
  value       = aws_db_instance.default.db_name
  description = "Nome do banco de dados criado na instância RDS."
}

output "db_username" {
  value       = aws_db_instance.default.username
  description = "Nome de usuário master do banco de dados RDS."
}

output "security_group_id" {
  value       = var.dms_security_group_id
  description = "ID do Security Group usado pelo RDS (mesmo SG da instância DMS)."
}

