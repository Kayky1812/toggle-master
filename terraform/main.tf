# ============================================================================
# 1. Módulo de Networking (VPC, Subnets Públicas/Privadas, IGW, NAT, Routes)
# ============================================================================
module "networking" {
  source = "./modules/networking"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = "${var.project_name}-cluster"
}

# ============================================================================
# 2. Módulo do Cluster EKS & Node Groups (Opção B: Conta Pessoal com IAM Roles)
# ============================================================================
module "eks" {
  source = "./modules/eks"

  project_name        = var.project_name
  cluster_name        = "${var.project_name}-cluster"
  cluster_version     = var.eks_cluster_version
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  public_subnet_ids   = module.networking.public_subnet_ids
  node_instance_types = var.eks_node_instance_types
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size
}

# ============================================================================
# 3. Módulo de Bancos de Dados (3 RDS PostgreSQL + 1 ElastiCache Redis + 1 DynamoDB)
# ============================================================================
module "databases" {
  source = "./modules/databases"

  project_name           = var.project_name
  vpc_id                 = module.networking.vpc_id
  private_subnet_ids     = module.networking.private_subnet_ids
  allowed_security_group = module.eks.cluster_security_group_id
  db_instance_class      = var.db_instance_class
  db_username            = var.db_username
  db_password            = var.db_password
  redis_node_type        = var.redis_node_type
}

# ============================================================================
# 4. Módulo de Mensageria (1 Fila AWS SQS)
# ============================================================================
module "messaging" {
  source = "./modules/messaging"

  queue_name = "toggle-master-events"
}

# ============================================================================
# 5. Módulo de Repositórios de Container (5 Repositórios no AWS ECR)
# ============================================================================
module "ecr" {
  source = "./modules/ecr"

  repositories = [
    "auth-service",
    "flag-service",
    "targeting-service",
    "evaluation-service",
    "analytics-service"
  ]
}

# ============================================================================
# 6. Módulo Kubernetes & Add-ons (ArgoCD, Ingress NGINX, KEDA, Secrets e DB Init)
# ============================================================================
module "k8s_addons" {
  source = "./modules/k8s_addons"

  aws_region             = var.aws_region
  rds_auth_endpoint      = module.databases.rds_auth_endpoint
  rds_flag_endpoint      = module.databases.rds_flag_endpoint
  rds_targeting_endpoint = module.databases.rds_targeting_endpoint
  redis_endpoint         = module.databases.redis_endpoint
  sqs_queue_url          = module.messaging.sqs_queue_url
  dynamodb_table_name    = module.databases.dynamodb_table_name
  db_username            = var.db_username
  db_password            = var.db_password
  master_key             = var.master_key
  service_api_key        = var.service_api_key
  oidc_provider_arn      = module.eks.oidc_provider_arn
  oidc_provider_url      = module.eks.oidc_provider_url

  depends_on = [
    module.eks,
    module.databases,
    module.messaging
  ]
}
