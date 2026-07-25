package httpserver

import (
	"encoding/json"
	"net/http"
)

// Stable, machine-readable error codes returned in the error envelope.
const (
	CodeUnauthenticated = "unauthenticated" // 401: caller's auth is missing/invalid/expired
	CodeUnavailable     = "unavailable"     // 503: a dependency (e.g. token key fetch) failed
	CodeInternal        = "internal"        // 500: unexpected server error
)

type errorEnvelope struct {
	Error errorBody `json:"error"`
}

type errorBody struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	RequestID string `json:"requestId"`
}

// WriteError writes the standard JSON error envelope with the given HTTP status.
// It never exposes a raw provider error — callers pass a safe, stable message.
func WriteError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(errorEnvelope{Error: errorBody{
		Code:      code,
		Message:   message,
		RequestID: RequestIDFrom(r.Context()),
	}})
}
