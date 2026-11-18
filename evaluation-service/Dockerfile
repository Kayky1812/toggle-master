# Etapa 1: Builder - Compila o código Go
FROM golang:1.22 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o evaluation-service .

# Etapa 2: Runtime
FROM alpine:3.20

RUN apk --no-cache upgrade && apk --no-cache add ca-certificates

WORKDIR /app

COPY --from=builder /app/evaluation-service .

ENV PORT=8004

EXPOSE 8004

CMD ["./evaluation-service"]
