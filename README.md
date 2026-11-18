# ToggleMaster — Plataforma Distribuída de Feature Flags (Fase 3: IaC, DevSecOps & GitOps)

O **ToggleMaster** é uma plataforma de gerenciamento e avaliação de *Feature Flags* em tempo real baseada em 5 microsserviços na nuvem **AWS** utilizando **Amazon EKS (Kubernetes)**. Na **Fase 3**, todos os scripts manuais e arquivos legados da Fase 2 foram eliminados e substituídos por uma arquitetura **100% declarativa** baseada em **Terraform (IaC)**, **Pipelines DevSecOps (GitHub Actions)** e **Entrega Contínua via GitOps (ArgoCD)**.

> * Para o passo a passo de execução dos comandos (`terraform plan/apply`, teste de falha/sucesso da pipeline DevSecOps e sincronização no ArgoCD), consulte **[TESTES.md](./TESTES.md)**.
> * Para o relatório de entrega da Fase 3 (decisões arquiteturais, desafios e estimativa de custos AWS), consulte **[RELATORIO_ENTREGA_FASE3.md](./RELATORIO_ENTREGA_FASE3.md)**.

---

## 1. Como os Problemas da Fase 2 Foram Resolvidos na Fase 3

| Problema Relatado no Desafio | Solução Implementada na Fase 3 |
| :--- | :--- |
| **"Os desenvolvedores estão rodando `kubectl apply` de suas máquinas locais, gerando conflitos de versão."** | Adotamos **GitOps puro com ArgoCD** (`argocd/applications-5-services.yaml`). O pipeline de CI atualiza a tag da imagem (`v1.0.0-<commit_hash>`) na pasta `k8s/` e o ArgoCD reconcilia automaticamente o cluster EKS (`selfHeal: true`, `prune: true`). |
| **"As credenciais do banco de dados estão sendo passadas em arquivos de texto sem segurança."** | O arquivo `k8s/01-config-secrets.yaml` foi **removido do Git**. Agora a `Secret` (`toggle-master-secrets`) e o `ConfigMap` são injetados diretamente na API do Kubernetes pelo módulo Terraform `k8s_addons` (`kubernetes_secret`), lendo os endpoints privados dos 3 RDS e do Redis direto do estado criptografado no S3. |
| **"Recentemente, uma vulnerabilidade em uma biblioteca Go passou despercebida e foi para produção."** | Implementamos **5 workflows DevSecOps** (`.github/workflows/`) com **SAST (`gosec` e `bandit`)**, **SCA (`Trivy fs`)** e **Container Scan (`Trivy image`)** configurados com `exit-code: '1'` para bloquear imediatamente qualquer vulnerabilidade `CRITICAL`. |
| **"Recriar o ambiente de homologação leva dias porque foi feito manualmente no console."** | Toda a infraestrutura AWS + add-ons do Kubernetes + inicialização dos schemas SQL nos 3 RDS são provisionados com um único `terraform apply` usando **6 módulos Terraform** e backend remoto em S3 com `use_lockfile = true`. |

---

## 2. Estrutura Limpa do Repositório (100% Fase 3)

```text
tech-challenge-fase-2/
├── terraform/                          # [1. INFRAESTRUTURA COMO CÓDIGO - TERRAFORM]
│   ├── backend.tf                      # Backend Remoto S3 (encrypt = true, use_lockfile = true)
│   ├── main.tf                         # Orquestração dos 6 módulos
│   ├── variables.tf                    # Variáveis parametrizadas e sensíveis
│   ├── outputs.tf                      # Outputs da VPC, EKS, 3 RDS, Redis, DynamoDB, SQS e 5 ECR
│   └── modules/
│       ├── networking/                 # VPC, 2 Subnets Públicas, 2 Privadas, IGW, NAT Gateway, Route Tables
│       ├── eks/                        # Cluster EKS 1.31, Managed Node Group e IAM Roles (Conta Pessoal)
│       ├── databases/                  # 3 instâncias RDS PostgreSQL, 1 ElastiCache Redis, 1 Tabela DynamoDB
│       ├── messaging/                  # 1 Fila AWS SQS (toggle-master-events)
│       ├── ecr/                        # 5 Repositórios no AWS ECR com scan_on_push = true
│       └── k8s_addons/                 # Injeta Secret/ConfigMap no K8s, Job SQL nos 3 RDS e Helm (ArgoCD/Ingress/KEDA)
│
├── .github/workflows/                  # [2. PIPELINES CI & DEVSECOPS - GITHUB ACTIONS]
│   ├── auth-service.yaml               # Go: Build & Test -> golangci-lint -> Gosec + Trivy -> Docker/ECR -> GitOps
│   ├── evaluation-service.yaml         # Go: Build & Test -> golangci-lint -> Gosec + Trivy -> Docker/ECR -> GitOps
│   ├── flag-service.yaml               # Python: Pytest -> Flake8 -> Bandit + Trivy -> Docker/ECR -> GitOps
│   ├── targeting-service.yaml          # Python: Pytest -> Flake8 -> Bandit + Trivy -> Docker/ECR -> GitOps
│   └── analytics-service.yaml          # Python: Pytest -> Flake8 -> Bandit + Trivy -> Docker/ECR -> GitOps
│
├── argocd/                             # [3. ENTREGA CONTÍNUA & GITOPS - ARGOCD]
│   └── applications-5-services.yaml    # Define as 5 Applications no ArgoCD monitorando a pasta k8s/
│
├── k8s/                                # [4. MANIFESTOS KUBERNETES (SEM CREDENCIAIS HARDCODED)]
│   ├── 00-namespace.yaml               # Namespace toggle-master
│   ├── 02-auth-service.yaml            # Deployment e Service do auth-service
│   ├── 03-flag-service.yaml            # Deployment e Service do flag-service
│   ├── 04-targeting-service.yaml       # Deployment e Service do targeting-service
│   ├── 05-evaluation-service.yaml      # Deployment e Service do evaluation-service
│   ├── 06-analytics-service.yaml       # Deployment e Service do analytics-service
│   ├── 07-ingress.yaml                 # Roteamento NGINX Ingress
│   ├── 08-hpa-evaluation.yaml          # HPA do evaluation-service
│   └── 09-keda-analytics.yaml          # KEDA ScaledObject do analytics-service
│
├── auth-service/                       # Microsserviço 1 (Go :8001) + Testes Unitários + SQL
├── flag-service/                       # Microsserviço 2 (Python :8002) + Testes Unitários + SQL
├── targeting-service/                  # Microsserviço 3 (Python :8003) + Testes Unitários + SQL
├── evaluation-service/                 # Microsserviço 4 (Go :8004) + Testes Unitários
├── analytics-service/                  # Microsserviço 5 (Python :8005) + Testes Unitários
├── TESTES.md                           # Roteiro de comandos para a demonstração em vídeo da Fase 3
├── RELATORIO_ENTREGA_FASE3.md          # Relatório de entrega (decisões, desafios e custos AWS)
└── README.md                           # Documentação geral da arquitetura
```
