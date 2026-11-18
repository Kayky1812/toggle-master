variable "aws_region" {
  description = "Região da AWS para provisionamento dos recursos"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome base do projeto"
  type        = string
  default     = "toggle-master"
}

variable "environment" {
  description = "Ambiente de implantação"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC principal"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Zonas de disponibilidade utilizadas na VPC"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Blocos CIDR das Subnets Públicas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Blocos CIDR das Subnets Privadas"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "eks_cluster_version" {
  description = "Versão do Kubernetes no Amazon EKS"
  type        = string
  default     = "1.31"
}

variable "eks_node_instance_types" {
  description = "Tipos de instância EC2 para o Node Group do EKS (t3.micro para compatibilidade com AWS Free Tier)"
  type        = list(string)
  default     = ["t3.micro"]
}

variable "eks_node_desired_size" {
  description = "Quantidade desejada de nós no Node Group (4 nós t3.micro para distribuir memória de 1GB/nó)"
  type        = number
  default     = 4
}

variable "eks_node_min_size" {
  description = "Quantidade mínima de nós no Node Group"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Quantidade máxima de nós no Node Group"
  type        = number
  default     = 5
}

variable "db_instance_class" {
  description = "Classe das 3 instâncias RDS PostgreSQL"
  type        = string
  default     = "db.t3.micro"
}

variable "db_username" {
  description = "Usuário master dos bancos RDS PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Senha master dos bancos RDS PostgreSQL"
  type        = string
  sensitive   = true
  default     = "postgres"
}

variable "redis_node_type" {
  description = "Tipo de nó do cluster ElastiCache Redis"
  type        = string
  default     = "cache.t3.micro"
}

variable "master_key" {
  description = "Chave mestre administrativa do auth-service (injetada na Secret K8s via Terraform)"
  type        = string
  sensitive   = true
  default     = "admin-secreto-123"
}

variable "service_api_key" {
  description = "Chave de API interna entre microsserviços (injetada na Secret K8s via Terraform)"
  type        = string
  sensitive   = true
  default     = "tm_key_123"
}

