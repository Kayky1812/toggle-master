package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestGenerateAndHashAPIKey(t *testing.T) {
	key, err := generateAPIKey()
	if err != nil {
		t.Fatalf("erro inesperado ao gerar chave: %v", err)
	}
	if !strings.HasPrefix(key, "tm_key_") {
		t.Errorf("esperava prefixo tm_key_, obteve %s", key)
	}

	hash1 := hashAPIKey(key)
	hash2 := hashAPIKey(key)
	if len(hash1) != 64 {
		t.Errorf("esperava hash SHA-256 de 64 caracteres, obteve %d", len(hash1))
	}
	if hash1 != hash2 {
		t.Errorf("hashAPIKey deve ser determinístico")
	}
}

func TestHealthHandler(t *testing.T) {
	app := &App{MasterKey: "test-master-key"}
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()

	app.healthHandler(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("esperava status 200, obteve %d", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), `"status":"ok"`) {
		t.Errorf("resposta inesperada no /health: %s", rec.Body.String())
	}
}

func TestMasterKeyMiddleware(t *testing.T) {
	app := &App{MasterKey: "secret-master"}
	nextHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	protected := app.masterKeyAuthMiddleware(nextHandler)

	// Caso 1: Sem token -> 403 Forbidden
	req1 := httptest.NewRequest(http.MethodPost, "/admin/keys", nil)
	rec1 := httptest.NewRecorder()
	protected.ServeHTTP(rec1, req1)
	if rec1.Code != http.StatusForbidden {
		t.Errorf("esperava 403 Forbidden sem chave mestre, obteve %d", rec1.Code)
	}

	// Caso 2: Com token correto -> 200 OK
	req2 := httptest.NewRequest(http.MethodPost, "/admin/keys", nil)
	req2.Header.Set("Authorization", "Bearer secret-master")
	rec2 := httptest.NewRecorder()
	protected.ServeHTTP(rec2, req2)
	if rec2.Code != http.StatusOK {
		t.Errorf("esperava 200 OK com chave mestre válida, obteve %d", rec2.Code)
	}
}

