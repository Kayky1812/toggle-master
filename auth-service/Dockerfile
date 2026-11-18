# Etapa 1: Builder - Compila o código Go (1.26 corrige CVE-2025-68121 na stdlib)
FROM golang:1.26 AS builder

WORKDIR /app

# Copia os arquivos de módulo
COPY go.mod go.sum ./

# Baixa as dependências
RUN go mod download

# Copia o código-fonte
COPY . .

# Compila a aplicação
RUN CGO_ENABLED=0 GOOS=linux go build -o auth-service .

# Etapa 2: Runtime - Imagem final (muito menor)
FROM alpine:3.20

# Instala o ca-certificates e atualiza pacotes OS contra CVEs
RUN apk --no-cache upgrade && apk --no-cache add ca-certificates

WORKDIR /app

# Copia apenas o binário compilado da etapa anterior
COPY --from=builder /app/auth-service .

# Define variáveis de ambiente padrão
ENV PORT=8001

# Expõe a porta
EXPOSE 8001

# Comando para iniciar o serviço
CMD ["./auth-service"]
