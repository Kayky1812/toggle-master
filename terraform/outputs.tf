output "vpc_id" {
  description = "ID da VPC criada pelo Terraform"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs das Subnets Públicas"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs das Subnets Privadas"
  value       = module.networking.private_subnet_ids
}

output "eks_cluster_name" {
  description = "Nome do Cluster Amazon EKS"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint da API do Cluster Amazon EKS"
  value       = module.eks.cluster_endpoint
}

output "rds_auth_endpoint" {
  description = "Endpoint do RDS PostgreSQL do auth-service"
  value       = module.databases.rds_auth_endpoint
}

output "rds_flag_endpoint" {
  description = "Endpoint do RDS PostgreSQL do flag-service"
  value       = module.databases.rds_flag_endpoint
}

output "rds_targeting_endpoint" {
  description = "Endpoint do RDS PostgreSQL do targeting-service"
  value       = module.databases.rds_targeting_endpoint
}

output "redis_endpoint" {
  description = "Endpoint do Cluster ElastiCache Redis"
  value       = module.databases.redis_endpoint
}

output "dynamodb_table_name" {
  description = "Nome da Tabela DynamoDB de Analytics"
  value       = module.databases.dynamodb_table_name
}

output "sqs_queue_url" {
  description = "URL da Fila SQS de eventos de avaliação"
  value       = module.messaging.sqs_queue_url
}

output "ecr_repository_urls" {
  description = "Mapa com as URLs dos 5 repositórios ECR"
  value       = module.ecr.repository_urls
}

