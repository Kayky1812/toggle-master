package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestGetDeterministicBucket(t *testing.T) {
	b1 := getDeterministicBucket("user-123" + "enable-new-dashboard")
	b2 := getDeterministicBucket("user-123" + "enable-new-dashboard")

	if b1 != b2 {
		t.Errorf("getDeterministicBucket deve retornar o mesmo valor para a mesma entrada: %d != %d", b1, b2)
	}
	if b1 < 0 || b1 >= 100 {
		t.Errorf("bucket fora do intervalo [0, 99]: %d", b1)
	}
}

func TestRunEvaluationLogic(t *testing.T) {
	app := &App{}

	// 1. Flag desativada deve retornar false
	infoDisabled := &CombinedFlagInfo{
		Flag: &Flag{Name: "test-flag", IsEnabled: false},
	}
	if app.runEvaluationLogic(infoDisabled, "user-1") {
		t.Errorf("esperava false quando a flag está desativada")
	}

	// 2. Flag ativada sem regra ativa deve retornar true
	infoNoRule := &CombinedFlagInfo{
		Flag: &Flag{Name: "test-flag", IsEnabled: true},
		Rule: nil,
	}
	if !app.runEvaluationLogic(infoNoRule, "user-1") {
		t.Errorf("esperava true quando a flag está ativa e não há regra")
	}

	// 3. Regra PERCENTAGE 100% deve retornar true
	info100 := &CombinedFlagInfo{
		Flag: &Flag{Name: "test-flag", IsEnabled: true},
		Rule: &TargetingRule{
			FlagName:  "test-flag",
			IsEnabled: true,
			Rules:     Rule{Type: "PERCENTAGE", Value: float64(100)},
		},
	}
	if !app.runEvaluationLogic(info100, "user-1") {
		t.Errorf("esperava true para rollout de 100%%")
	}

	// 4. Regra PERCENTAGE 0% deve retornar false
	info0 := &CombinedFlagInfo{
		Flag: &Flag{Name: "test-flag", IsEnabled: true},
		Rule: &TargetingRule{
			FlagName:  "test-flag",
			IsEnabled: true,
			Rules:     Rule{Type: "PERCENTAGE", Value: float64(0)},
		},
	}
	if app.runEvaluationLogic(info0, "user-1") {
		t.Errorf("esperava false para rollout de 0%%")
	}
}

func TestHealthAndValidationEvaluationHandler(t *testing.T) {
	app := &App{}

	// Health check
	reqHealth := httptest.NewRequest(http.MethodGet, "/health", nil)
	recHealth := httptest.NewRecorder()
	app.healthHandler(recHealth, reqHealth)
	if recHealth.Code != http.StatusOK || !strings.Contains(recHealth.Body.String(), `"status":"ok"`) {
		t.Errorf("falha no health check: code=%d body=%s", recHealth.Code, recHealth.Body.String())
	}

	// /evaluate sem query params -> 400 Bad Request
	reqEval := httptest.NewRequest(http.MethodGet, "/evaluate", nil)
	recEval := httptest.NewRecorder()
	app.evaluationHandler(recEval, reqEval)
	if recEval.Code != http.StatusBadRequest {
		t.Errorf("esperava 400 Bad Request quando faltam parâmetros, obteve %d", recEval.Code)
	}
}

