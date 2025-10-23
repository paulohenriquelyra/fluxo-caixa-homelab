# ==============================================================================
# SAÍDAS (OUTPUTS) DO AMBIENTE
# ==============================================================================
#
# Outputs expõem informações sobre os recursos criados para o usuário ou para
# outros sistemas. Após executar `terraform apply`, os valores dos outputs
# são exibidos no console.
#
# Eles são especialmente úteis para obter informações de conexão, como endpoints
# de banco de dados, IPs de load balancers, etc.
#
# Aqui, estamos simplesmente "passando através" dos outputs dos módulos `aurora` e `network`
# para que eles fiquem visíveis no nível do ambiente (root).

# ========================================
# SAÍDAS DO MÓDULO AURORA
# ========================================

output "aurora_cluster_endpoint" {
  description = "Endpoint de escrita (writer) do cluster Aurora. Use este para conectar sua aplicação para operações de leitura e escrita."
  value       = module.aurora.cluster_endpoint
  sensitive   = true # Marca o output como sensível para não exibi-lo nos logs.
}

output "aurora_cluster_reader_endpoint" {
  description = "Endpoint de leitura (reader) do cluster Aurora. Use este para cargas de trabalho de apenas leitura, como relatórios e dashboards."
  value       = module.aurora.cluster_reader_endpoint
  sensitive   = true
}

output "aurora_cluster_port" {
  description = "Porta de conexão do cluster Aurora."
  value       = module.aurora.cluster_port
}

output "aurora_master_password_secret_arn" {
  description = "ARN do segredo no AWS Secrets Manager que contém a senha mestre. Você pode usar este ARN para conceder permissões de acesso à senha para outras aplicações ou serviços via IAM."
  value       = module.aurora.master_password_secret_arn
  sensitive   = true
}

output "aurora_security_group_id" {
  description = "O ID do Security Group associado ao cluster Aurora. Útil para adicionar regras de entrada a partir de outros recursos (ex: instâncias EC2, DMS)."
  value       = module.aurora.security_group_id
}

# ========================================
# SAÍDAS DO MÓDULO DE REDE
# ========================================

output "vpc_id" {
  description = "ID da VPC criada para o ambiente."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Lista de IDs das sub-redes públicas. Útil para implantar recursos que precisam de acesso à internet, como Load Balancers."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Lista de IDs das sub-redes privadas. Usado pelo Aurora e outros serviços de backend."
  value       = module.network.private_subnet_ids
}


_# ========================================
# SAÍDAS DO MÓDULO DMS
# ========================================

output "dms_replication_task_arn" {
  description = "O ARN da tarefa de replicação DMS. Use este ARN para iniciar, parar ou monitorar a tarefa via AWS CLI."
  value       = module.dms.replication_task_arn
}

