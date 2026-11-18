# Relatório de Entrega — Tech Challenge Fase 3 (DevSecOps, IaC & GitOps)

## 1. Identificação do Grupo / Participantes

* **Participante(s):** Kayky *(adicione os nomes completos e RMs dos demais integrantes do grupo, se houver)*
* **Curso / Turma:** Pós-Tech FIAP — DevOps & Cloud Architecture (Fase 3)
* **Repositório do Projeto (Código Fonte, Terraform, Workflows e GitOps):** `https://github.com/SEU_USUARIO/tech-challenge-fase-2`
* **Link do Vídeo de Demonstração (até 20 min):** `[INSERIR_LINK_DO_YOUTUBE_OU_DRIVE_AQUI]`

---

## 2. Resumo da Arquitetura e Implementação da Fase 3

Para eliminar os problemas operacionais da Fase 2 (deploys manuais via `kubectl apply`, configuração manual no console AWS e ausência de barreiras de segurança contra bibliotecas vulneráveis), toda a plataforma **ToggleMaster** (5 microsserviços em Go e Python) foi reestruturada seguindo os pilares de **Infraestrutura Imutável (Terraform)**, **Pipelines DevSecOps (GitHub Actions)** e **Entrega Contínua via GitOps (ArgoCD)**:

1. **Infraestrutura como Código (`terraform/`):**
   * Projeto modularizado em 6 módulos independentes (`networking`, `eks`, `databases`, `messaging`, `ecr` e `k8s_addons`), eliminando 100% dos scripts shell manuais da Fase 2.
   * **Networking:** VPC dedicada (`10.0.0.0/16`), 2 Subnets Públicas, 2 Subnets Privadas distribuídas em múltiplas zonas de disponibilidade (`us-east-1a` e `us-east-1b`), Internet Gateway, NAT Gateway e Route Tables.
   * **Cluster EKS & IAM (Opção B — Conta Pessoal):** Cluster Amazon EKS (`1.31`), Managed Node Group (`standard-workers`) e IAM Roles dedicadas com princípio de privilégio mínimo para Control Plane e Worker Nodes.
   * **Camada de Dados Isolada:** **3 instâncias RDS PostgreSQL** dedicadas (`rds-auth-service`, `rds-flag-service`, `rds-targeting-service`), **1 Cluster ElastiCache Redis** (`toggle-redis-v2`) em subnets privadas protegidas por Security Group exclusivo e **1 Tabela DynamoDB** (`ToggleMasterAnalytics`).
   * **Injeção Segura de Credenciais e Add-ons (`k8s_addons`):** Elimina o arquivo de texto `01-config-secrets.yaml` do repositório Git; o próprio Terraform cria a `kubernetes_secret` e o `kubernetes_config_map` diretamente no cluster com os endpoints gerados, executa um `kubernetes_job` (`rds-schema-initializer`) para aplicar os schemas SQL nos 3 bancos RDS e instala o **ArgoCD**, **NGINX Ingress**, **Metrics Server** e **KEDA** via provider `helm`.
   * **Mensageria & Imagens:** **1 Fila AWS SQS** (`toggle-master-events`) e **5 Repositórios no Amazon ECR** com `scan_on_push = true`.
   * **Estado Remoto e Lock Nativo:** Configurado `backend "s3"` com criptografia (`encrypt = true`) e a flag `use_lockfile = true` (S3 Native State Locking).

2. **Pipelines de CI & DevSecOps (`.github/workflows/`):**
   * 5 workflows independentes (`auth-service.yaml`, `flag-service.yaml`, `targeting-service.yaml`, `evaluation-service.yaml`, `analytics-service.yaml`) acionados em `push` e `pull_request` na branch `main`.
   * **Job 1 — Build & Unit Test:** Compilação e execução de testes unitários automatizados (`go test -v ./...` para os serviços em Go e `pytest -v` para os serviços em Python).
   * **Job 2 — Linter / Static Analysis:** `golangci-lint` nos microsserviços Go e `flake8` nos microsserviços Python.
   * **Job 3 — Security Scan (SAST & SCA) com Regra de Bloqueio:**
     * **SAST:** `gosec` (para Go) e `bandit` (para Python) verificando falhas de segurança no código-fonte.
     * **SCA:** `Trivy` em modo filesystem (`scan-type: fs`) analisando `go.mod`/`go.sum` e `requirements.txt` com `exit-code: '1'` para severidade `CRITICAL`.
   * **Job 4 — Docker Build, Container Scan, ECR Push & GitOps:** Constrói a imagem multi-stage, executa scan de container com `Trivy` (`exit-code: '1'` em `CRITICAL`), publica no AWS ECR com tag imutável baseada no hash do commit (`v1.0.0-<short_sha>`) e atualiza automaticamente o manifesto Kubernetes na pasta `k8s/`.

3. **Entrega Contínua (CD) & GitOps (`argocd/` e `k8s/`):**
   * O **ArgoCD** monitora continuamente a pasta `k8s/` do repositório na branch `main` com política de sincronização automática (`automated: { prune: true, selfHeal: true }`), gerenciando os 5 microsserviços sem necessidade de acesso manual via `kubectl apply`.

---

## 3. Desafios Encontrados e Decisões Tomadas

1. **Separação Física dos 3 Bancos PostgreSQL no RDS (Database per Service):**
   * *Desafio:* Na Fase 2, os bancos `flags_db` e `targeting_db` compartilhavam uma mesma instância RDS para economizar tempo de criação manual. Na Fase 3, o requisito técnico exigiu explicitamente **3 instâncias RDS PostgreSQL** isoladas via Terraform.
   * *Decisão:* Criamos 3 recursos `aws_db_instance` independentes no módulo `terraform/modules/databases` (`rds-auth-service`, `rds-flag-service` e `rds-targeting-service`), cada um inicializado automaticamente com seu respectivo schema (`auth_db`, `flags_db` e `targeting_db`) e isolado nas subnets privadas com liberação na porta `5432` exclusivamente para o Security Group do cluster EKS.

2. **Adequação Criptográfica e Remediação de Alertas SAST/SCA (Gosec, Bandit e Trivy):**
   * *Desafio:* Ao introduzir o `gosec` nos serviços Go e o `bandit` nos serviços Python com regra de bloqueio ativo, foram detectados pontos de atenção do código legado da Fase 2: uso de `crypto/sha1` para cálculo de hash de bucket no `evaluation-service` (alerta G401/G505), servidor HTTP sem `ReadHeaderTimeout` contra ataques Slowloris (G112) e construção de query `UPDATE` com f-string no `flag-service` e `targeting-service` (Bandit B608). Além disso, versões antigas do Flask (`2.3.3`) e imagens base Alpine `3.19` acusavam CVEs em scans do Trivy.
   * *Decisão:* Substituímos `crypto/sha1` por `crypto/sha256` no `evaluation-service`, configuramos `http.Server` com `ReadHeaderTimeout: 5 * time.Second` nos serviços Go, refatoramos as queries SQL no Python para strings estáticas parametrizadas e atualizamos as dependências (`Flask 3.0.3`, `Werkzeug 3.0.6`, `requests 2.32.3`, `alpine:3.20` com `apk upgrade`), garantindo pipelines 100% verdes em estado normal e bloqueio imediato quando uma vulnerabilidade é injetada.

3. **Prevenção de Loop Infinito no GitOps:**
   * *Desafio:* Como optamos pela arquitetura de Monorepo (mantendo o código-fonte dos microsserviços e a pasta `k8s/` de GitOps no mesmo repositório), o commit automático feito pelo GitHub Actions para atualizar a tag da imagem poderia disparar novamente o próprio workflow em loop.
   * *Decisão:* Configuramos filtros de caminho (`paths: ['<service>/**']`) nos gatilhos dos workflows de cada microsserviço e adicionamos `[skip ci]` na mensagem do commit de atualização do manifesto Kubernetes (`chore(gitops): update <service> image to v1.0.0-<sha> [skip ci]`), isolando o ciclo de CI do ciclo de reconciliação do ArgoCD.

---

## 4. Estimativa de Custos Mensais da AWS (AWS Pricing Calculator — Região `us-east-1`)

Abaixo está o detalhamento da estimativa de custos na região **US East (N. Virginia)** para manter toda a infraestrutura provisionada pelo Terraform em operação contínua (730 horas/mês):

| Serviço AWS | Especificação / Recurso Provisionado pelo Terraform | Quantidade | Custo Mensal Estimado (USD) |
| :--- | :--- | :---: | :---: |
| **Amazon VPC & NAT Gateway** | 1 NAT Gateway (`us-east-1a`) + Elastic IP + Processamento de dados (~10 GB) | 1 | \$33.30 |
| **Amazon EKS (Control Plane)** | Cluster Kubernetes Gerenciado (`toggle-master-cluster` v1.31) | 1 cluster | \$73.00 |
| **Amazon EC2 (EKS Worker Nodes)** | Instâncias `t3.medium` (On-Demand, Linux) + 20 GB EBS `gp2` por nó | 2 nós | \$64.77 |
| **Amazon Elastic Load Balancing** | Application/Network Load Balancer provisionado pelo NGINX Ingress | 1 LB | \$18.40 |
| **Amazon RDS for PostgreSQL** | Instâncias `db.t3.micro` (Single-AZ, 20 GB Storage `gp2` cada: `auth`, `flag`, `targeting`) | 3 instâncias | \$45.42 |
| **Amazon ElastiCache for Redis** | Nó `cache.t3.micro` (`toggle-redis-v2`, 1 nó sem réplica) | 1 cluster | \$12.41 |
| **Amazon DynamoDB** | Tabela `ToggleMasterAnalytics` (Modo On-Demand `PAY_PER_REQUEST`, < 1M leituras/escritas) | 1 tabela | \$1.25 |
| **Amazon SQS** | Fila padrão `toggle-master-events` (Primeiros 1M requests gratuitos no Free Tier) | 1 fila | \$0.00 |
| **Amazon ECR & Amazon S3** | 5 Repositórios ECR (~2 GB imagens) + 1 Bucket S3 para `terraform.tfstate` | 5 repos + 1 bucket | \$0.25 |
| **TOTAL MENSAL ESTIMADO (24x7)** | **Infraestrutura Completa da Fase 3** | — | **\$248.80 / mês** |

*(Observação: Executando `terraform destroy` após os testes e gravação do vídeo, o custo em repouso cai para **\$0.00/h**, mantendo apenas frações de centavos do arquivo de estado no S3).*

> **Print da Estimativa de Custos (AWS Pricing Calculator):**
> *(Ao exportar este relatório para PDF para entrega na plataforma da FIAP, anexe abaixo o print da tela do [AWS Pricing Calculator](https://calculator.aws/) com os itens da tabela acima).*

