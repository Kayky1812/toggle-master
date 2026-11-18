# Etapa 1: Builder
FROM python:3.11-slim AS builder

WORKDIR /app

# Copia requirements e instala dependências
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Etapa 2: Runtime
FROM python:3.11-slim

RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/* && pip install --no-cache-dir --upgrade pip setuptools wheel

WORKDIR /app

# Copia o diretório de site-packages do builder
COPY --from=builder /root/.local /root/.local

# Copia o código-fonte
COPY . .

# Adiciona o diretório do pip ao PATH
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

# Porta padrão
ENV PORT=8002

EXPOSE 8002

# Comando para iniciar
CMD ["gunicorn", "--bind", "0.0.0.0:8002", "app:app"]
