variable "aws_region" {
  type = string
}

variable "rds_auth_endpoint" {
  type = string
}

variable "rds_flag_endpoint" {
  type = string
}

variable "rds_targeting_endpoint" {
  type = string
}

variable "redis_endpoint" {
  type = string
}

variable "sqs_queue_url" {
  type = string
}

variable "dynamodb_table_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "master_key" {
  type      = string
  sensitive = true
}

variable "service_api_key" {
  type      = string
  sensitive = true
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

# ============================================================================
# 1. Namespace toggle-master, IRSA (IAM Role + ServiceAccount) + ConfigMap e Secret
#    (Resolve o problema da Fase 2 de credenciais passadas em arquivos de texto
#     e autentica evaluation-service, analytics-service e KEDA via OIDC/IRSA!)
# ============================================================================
resource "kubernetes_namespace" "toggle_master" {
  metadata {
    name = "toggle-master"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "aws_iam_role" "toggle_master_irsa" {
  name = "toggle-master-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = [
              "system:serviceaccount:toggle-master:toggle-master-sa",
              "system:serviceaccount:keda:keda-operator"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "toggle_master_irsa_policy" {
  name = "toggle-master-sqs-dynamodb-policy"
  role = aws_iam_role.toggle_master_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:*",
          "dynamodb:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "kubernetes_service_account" "toggle_master_sa" {
  metadata {
    name      = "toggle-master-sa"
    namespace = kubernetes_namespace.toggle_master.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.toggle_master_irsa.arn
    }
  }
}

resource "kubernetes_config_map" "toggle_master_config" {
  metadata {
    name      = "toggle-master-config"
    namespace = kubernetes_namespace.toggle_master.metadata[0].name
  }

  data = {
    AWS_REGION            = var.aws_region
    AWS_DYNAMODB_TABLE    = var.dynamodb_table_name
    AWS_SQS_URL           = var.sqs_queue_url
    AUTH_SERVICE_URL      = "http://auth-service:8001"
    FLAG_SERVICE_URL      = "http://flag-service:8002"
    TARGETING_SERVICE_URL = "http://targeting-service:8003"
  }
}

resource "kubernetes_secret" "toggle_master_secrets" {
  metadata {
    name      = "toggle-master-secrets"
    namespace = kubernetes_namespace.toggle_master.metadata[0].name
  }

  type = "Opaque"

  data = {
    MASTER_KEY             = var.master_key
    SERVICE_API_KEY        = var.service_api_key
    DB_PASSWORD            = var.db_password
    AUTH_DATABASE_URL      = "postgres://${var.db_username}:${var.db_password}@${var.rds_auth_endpoint}:5432/auth_db"
    FLAG_DATABASE_URL      = "postgres://${var.db_username}:${var.db_password}@${var.rds_flag_endpoint}:5432/flags_db"
    TARGETING_DATABASE_URL = "postgres://${var.db_username}:${var.db_password}@${var.rds_targeting_endpoint}:5432/targeting_db"
    REDIS_URL              = "redis://${var.redis_endpoint}:6379"
  }
}

# ============================================================================
# 2. Job Kubernetes declarativo para inicializar os Schemas SQL nos 3 RDS
# ============================================================================
resource "kubernetes_config_map" "db_init_sql" {
  metadata {
    name      = "toggle-master-db-init-sql"
    namespace = kubernetes_namespace.toggle_master.metadata[0].name
  }

  data = {
    "auth_init.sql"      = file("${path.module}/../../../auth-service/db/init.sql")
    "flag_init.sql"      = file("${path.module}/../../../flag-service/db/init.sql")
    "targeting_init.sql" = file("${path.module}/../../../targeting-service/db/init.sql")
  }
}

resource "kubernetes_job" "db_schema_init" {
  metadata {
    name      = "rds-schema-initializer"
    namespace = kubernetes_namespace.toggle_master.metadata[0].name
  }

  spec {
    ttl_seconds_after_finished = 300
    backoff_limit              = 4

    template {
      metadata {
        labels = {
          job = "rds-schema-initializer"
        }
      }
      spec {
        restart_policy = "OnFailure"

        container {
          name  = "psql-init"
          image = "postgres:15-alpine"

          env {
            name = "AUTH_DB_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.toggle_master_secrets.metadata[0].name
                key  = "AUTH_DATABASE_URL"
              }
            }
          }

          env {
            name = "FLAG_DB_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.toggle_master_secrets.metadata[0].name
                key  = "FLAG_DATABASE_URL"
              }
            }
          }

          env {
            name = "TARGETING_DB_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.toggle_master_secrets.metadata[0].name
                key  = "TARGETING_DATABASE_URL"
              }
            }
          }

          command = ["/bin/sh", "-c"]
          args = [
            "psql \"$AUTH_DB_URL\" -f /sql/auth_init.sql && psql \"$FLAG_DB_URL\" -f /sql/flag_init.sql && psql \"$TARGETING_DB_URL\" -f /sql/targeting_init.sql"
          ]

          volume_mount {
            name       = "sql-scripts"
            mount_path = "/sql"
            read_only  = true
          }
        }

        volume {
          name = "sql-scripts"
          config_map {
            name = kubernetes_config_map.db_init_sql.metadata[0].name
          }
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = "5m"
    update = "5m"
  }
}

# ============================================================================
# 3. Instalação dos Add-ons do Cluster via Helm (ArgoCD, Ingress NGINX, KEDA)
# ============================================================================
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.7.10"

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  # Otimização para instâncias t3.micro (1GB RAM - AWS Free Tier):
  # Desativa controladores opcionais (Dex SSO e Notifications) que não são usados
  # no desafio, economizando 2 Pods e ~200 MB de memória no cluster.
  set {
    name  = "dex.enabled"
    value = "false"
  }

  set {
    name  = "notifications.enabled"
    value = "false"
  }
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.11.3"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.2"
}

resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  namespace        = "keda"
  create_namespace = true
  version          = "2.15.1"

  set {
    name  = "serviceAccount.operator.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.toggle_master_irsa.arn
  }
}

