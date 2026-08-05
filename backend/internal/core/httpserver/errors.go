package httpserver

import (
	"encoding/json"
	"net/http"
)

// Stable, machine-readable error codes returned in the error envelope.
const (
	CodeUnauthenticated = "unauthenticated"  // 401: caller's auth is missing/invalid/expired
	CodeUnavailable     = "unavailable"      // 503: a dependency (e.g. token key fetch) failed
	CodeInternal        = "internal"         // 500: unexpected server error
	CodeInvalidArgument = "invalid_argument" // 400: request failed validation
	CodeUsernameTaken   = "username_taken"   // 409: username already in use
	CodeInvalidTimezone = "invalid_timezone" // 400: not a valid IANA timezone
	CodeRateLimited     = "rate_limited"     // 429: per-user rate limit exceeded
	CodeNotFound        = "not_found"        // 404: no route matches this API path/method
	CodeForbidden       = "forbidden"        // 403: authenticated but not allowed to act on this resource
	CodeConflict        = "conflict"         // 409: request conflicts with the resource's current state
)

type errorEnvelope struct {
	Error errorBody `json:"error"`
}

type errorBody struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	RequestID string `json:"requestId"`
}

// DecodeJSON decodes the request body into dst, rejecting unknown fields. On
// failure it writes a 400 invalid-argument envelope and returns false, so a
// handler can `if !DecodeJSON(...) { return }`. It reuses CodeInvalidArgument
// (the codebase's canonical 400 validation code) rather than a second code.
func DecodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		WriteError(w, r, http.StatusBadRequest, CodeInvalidArgument, "invalid request body")
		return false
	}
	return true
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
