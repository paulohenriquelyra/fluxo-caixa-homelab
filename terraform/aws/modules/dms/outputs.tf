output "replication_task_arn" {
  description = "O ARN da tarefa de replicação DMS. Use este ARN para iniciar, parar ou monitorar a tarefa."
  value       = aws_dms_replication_task.dms_task.replication_task_arn
}

output "replication_instance_arn" {
  description = "O ARN da instância de replicação DMS."
  value       = aws_dms_replication_instance.dms_instance.replication_instance_arn
}

