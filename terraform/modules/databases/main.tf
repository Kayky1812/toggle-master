variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "allowed_security_group" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "redis_node_type" {
  type = string
}

# ============================================================================
# Security Group dedicado para RDS PostgreSQL (5432) e ElastiCache Redis (6379)
# ============================================================================
resource "aws_security_group" "data_plane" {
  name        = "${var.project_name}-data-sg"
  description = "Libera acesso aos bancos RDS PostgreSQL (5432) e Redis (6379) a partir do cluster EKS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS Cluster SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.allowed_security_group]
  }

  ingress {
    description     = "Redis from EKS Cluster SG"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.allowed_security_group]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-data-sg"
  }
}

# ============================================================================
# 3 Instâncias RDS PostgreSQL (Database per Service: auth, flag e targeting)
# ============================================================================
resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-rds-subnet-group"
  }
}

resource "aws_db_instance" "auth" {
  identifier              = "rds-auth-service"
  db_name                 = "auth_db"
  engine                  = "postgres"
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  storage_type            = "gp2"
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.rds.name
  vpc_security_group_ids  = [aws_security_group.data_plane.id]
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name    = "rds-auth-service"
    Service = "auth-service"
  }
}

resource "aws_db_instance" "flag" {
  identifier              = "rds-flag-service"
  db_name                 = "flags_db"
  engine                  = "postgres"
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  storage_type            = "gp2"
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.rds.name
  vpc_security_group_ids  = [aws_security_group.data_plane.id]
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name    = "rds-flag-service"
    Service = "flag-service"
  }
}

resource "aws_db_instance" "targeting" {
  identifier              = "rds-targeting-service"
  db_name                 = "targeting_db"
  engine                  = "postgres"
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  storage_type            = "gp2"
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.rds.name
  vpc_security_group_ids  = [aws_security_group.data_plane.id]
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name    = "rds-targeting-service"
    Service = "targeting-service"
  }
}

# ============================================================================
# 1 Cluster ElastiCache (Redis)
# ============================================================================
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "toggle-redis-v2"
  engine               = "redis"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.data_plane.id]

  tags = {
    Name    = "toggle-redis-v2"
    Service = "evaluation-service"
  }
}

# ============================================================================
# 1 Tabela DynamoDB (ToggleMasterAnalytics)
# ============================================================================
resource "aws_dynamodb_table" "analytics" {
  name         = "ToggleMasterAnalytics"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name    = "ToggleMasterAnalytics"
    Service = "analytics-service"
  }
}

output "rds_auth_endpoint" {
  value = aws_db_instance.auth.address
}

output "rds_flag_endpoint" {
  value = aws_db_instance.flag.address
}

output "rds_targeting_endpoint" {
  value = aws_db_instance.targeting.address
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.analytics.name
}

