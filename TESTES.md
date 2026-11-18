# Guia Passo a Passo de Execução e Demonstração — ToggleMaster (Fase 3)

Este documento reúne todos os comandos nativos (`terraform`, `git` e `kubectl`) na ordem exata exigida pelos entregáveis do **Tech Challenge Fase 3** (IaC com Terraform, Pipeline DevSecOps, GitOps e ArgoCD), **sem uso de scripts manuais (`reativar.sh` / `kubectl apply` de deployments)**.

================================================================================
ETAPA 1: INFRAESTRUTURA COMO CÓDIGO (100% TERRAFORM + BACKEND REMOTO S3)
================================================================================

PASSO 01 — Criar o Bucket S3 do Estado Remoto (Executar 1 única vez na conta AWS)
(O Terraform exige que o bucket S3 onde o `terraform.tfstate` será guardado exista antes do `terraform init`).

👉 COPIE E COLE NO TERMINAL:


ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3api create-bucket --bucket "toggle-master-tfstate-${ACCOUNT_ID}" --region us-east-1 2>/dev/null || true
aws s3api put-bucket-versioning --bucket "toggle-master-tfstate-${ACCOUNT_ID}" --versioning-configuration Status=Enabled


--------------------------------------------------------------------------------

PASSO 02 — Executar `terraform init`, `terraform plan` e `terraform apply`
(Exigido no vídeo: "Mostre o `terraform plan` e o `terraform apply` rodando ou o resultado final na AWS: VPCs, RDS, EKS criados via código").
O Terraform cria automaticamente:
1. Networking (VPC, Subnets Públicas/Privadas, IGW, NAT Gateway, Route Tables);
2. Cluster EKS 1.31 + Managed Node Group + IAM Roles;
3. 3 instâncias RDS PostgreSQL (`rds-auth-service`, `rds-flag-service`, `rds-targeting-service`), 1 ElastiCache Redis e 1 Tabela DynamoDB (`ToggleMasterAnalytics`);
4. 1 Fila SQS (`toggle-master-events`) e 5 Repositórios no ECR;
5. Módulo `k8s_addons`: Injeta diretamente no EKS o `ConfigMap` e a `Secret` (sem expor credenciais do banco em arquivos de texto no Git), roda o Job `rds-schema-initializer` que cria as tabelas SQL nos 3 RDS, e instala o **ArgoCD**, **NGINX Ingress**, **Metrics Server** e **KEDA** via Helm.

👉 COPIE E COLE NO TERMINAL:


cd ~/tech-challenge-fase-2/terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan


--------------------------------------------------------------------------------

PASSO 03 — Demonstrar o Estado Remoto no S3 com `use_lockfile` e os Outputs do Terraform
(Comprova o requisito de Estado Remoto no S3 e exibe os endpoints gerados).

👉 COPIE E COLE NO TERMINAL:


cd ~/tech-challenge-fase-2/terraform
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 ls "s3://toggle-master-tfstate-${ACCOUNT_ID}/fase3/"
terraform output
aws eks update-kubeconfig --name "$(terraform output -raw eks_cluster_name)" --region us-east-1
cd ~/tech-challenge-fase-2


================================================================================
ETAPA 2: ENTREGA CONTÍNUA (CD) & GITOPS COM ARGOCD
================================================================================

PASSO 04 — Conectar o ArgoCD ao Repositório de GitOps (`k8s/`)
(Registra as 5 Applications no ArgoCD apontando para a pasta `k8s/` do seu repositório GitHub. A partir deste momento, **todo o deploy dos 5 microsserviços é feito exclusivamente pelo ArgoCD via GitOps**, sem `kubectl apply` manual nos serviços).

👉 COPIE E COLE NO TERMINAL:


cd ~/tech-challenge-fase-2
GIT_URL=$(git config --get remote.origin.url | sed -E 's|^git@github\.com:(.*)|https://github.com/\1|')
sed -i "s|repoURL: .*|repoURL: ${GIT_URL}|g" argocd/applications-5-services.yaml
kubectl apply -f argocd/applications-5-services.yaml
kubectl get applications -n argocd


--------------------------------------------------------------------------------

PASSO 05 — Expor a Interface Web (UI) do ArgoCD e obter a senha de admin
(Exigido no vídeo: "Mostre a interface do ArgoCD gerenciando os 5 microsserviços". Abra `http://localhost:8080` no navegador e faça login com `admin` e a senha abaixo).

👉 COPIE E COLE NO TERMINAL:


echo "Usuário: admin"
echo -n "Senha: " && kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo ""
kubectl port-forward svc/argocd-server -n argocd 8080:80 >/dev/null 2>&1 &
echo "Interface do ArgoCD disponível em: http://localhost:8080"


================================================================================
ETAPA 3: DEMONSTRAÇÃO DO PIPELINE DEVSECOPS (FALHANDO E PASSANDO) + GITOPS
================================================================================

PASSO 06 — Configurar as Secrets da AWS no GitHub Actions (Executar 1 única vez)
(Permite que os 5 workflows façam login e push no AWS ECR).

👉 COPIE E COLE NO TERMINAL:


gh secret set AWS_ACCESS_KEY_ID --body "$(aws configure get aws_access_key_id)"
gh secret set AWS_SECRET_ACCESS_KEY --body "$(aws configure get aws_secret_access_key)"


--------------------------------------------------------------------------------

PASSO 07 — Simular Vulnerabilidade Crítica / SAST para FALHAR o Pipeline DevSecOps
(Exigido no vídeo: "Faça uma alteração no código de um microsserviço — ex: insira um erro proposital ou uma dependência vulnerável — e mostre o pipeline falhando no passo de segurança").
O comando abaixo injeta uma dependência com CVE crítica (`pyyaml==5.3.1`) e código inseguro (`subprocess.Popen(..., shell=True)`) no `flag-service`, disparando o workflow no GitHub Actions e bloqueando a execução no Job **3. Security Scan (SAST & SCA)**.

👉 COPIE E COLE NO TERMINAL:


cd ~/tech-challenge-fase-2
echo "pyyaml==5.3.1" >> flag-service/requirements.txt
cat << 'EOF' >> flag-service/app.py

# Função insegura adicionada propositalmente para demonstrar bloqueio SAST (Bandit B602)
import subprocess
def insecure_debug_cmd(user_input):
    return subprocess.Popen(user_input, shell=True)
EOF

git add flag-service/requirements.txt flag-service/app.py
git commit -m "test(security): introduce intentional SAST and SCA vulnerability in flag-service"
git push origin main


--------------------------------------------------------------------------------

PASSO 08 — Corrigir a Vulnerabilidade e Mostrar o Pipeline PASSANDO + Atualização GitOps + Sync no ArgoCD
(Exigido no vídeo: "Depois corrija e mostre passando. Mostre o pipeline atualizando a tag da imagem no repositório de GitOps. Mostre o ArgoCD detectando a mudança e sincronizando a nova versão no cluster automaticamente").

👉 COPIE E COLE NO TERMINAL:


cd ~/tech-challenge-fase-2
git revert --no-edit HEAD
git push origin main


--------------------------------------------------------------------------------

PASSO 09 — Verificar a nova tag `v1.0.0-<hash>` commitada pelo Pipeline e sincronizada pelo ArgoCD no EKS

👉 COPIE E COLE NO TERMINAL:


cd ~/tech-challenge-fase-2
git pull origin main
git log -n 3 --oneline
grep "image:" k8s/03-flag-service.yaml
kubectl get applications -n argocd
kubectl get deployment flag-service -n toggle-master -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'


================================================================================
ETAPA 4: VALIDAÇÃO RÁPIDA DOS 5 MICROSSERVIÇOS SINCRONIZADOS PELO ARGOCD
================================================================================

PASSO 10 — Testar os 5 Microsserviços via Load Balancer do Ingress

👉 COPIE E COLE NO TERMINAL:


export ALB_URL="http://$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "URL do Load Balancer: $ALB_URL"

curl -i "${ALB_URL}/auth/health"
curl -i "${ALB_URL}/flags/health"
curl -i "${ALB_URL}/targeting/health"
curl -i "${ALB_URL}/eval/health"
curl -i "${ALB_URL}/analytics/health"


================================================================================
ETAPA 5: DESTRUIÇÃO DA INFRAESTRUTURA (100% TERRAFORM DESTROY)
================================================================================

PASSO 11 — Destruir todo o ambiente com `terraform destroy`
(Remove as Applications do ArgoCD para liberar o Load Balancer e destrói toda a infraestrutura via Terraform).

👉 COPIE E COLE NO TERMINAL:


pkill -f "port-forward svc/argocd-server" 2>/dev/null || true
kubectl delete applications --all -n argocd --ignore-not-found=true
cd ~/tech-challenge-fase-2/terraform
terraform destroy
