package web

import (
	"net"
	"net/http"
	"strings"
)

// clientIP returns the leftmost X-Forwarded-For entry (the original client as
// seen by Caddy), falling back to RemoteAddr. NOTE: X-Forwarded-For is
// client-spoofable; this bounds casual abuse, not a determined attacker --
// escalate to Cloudflare Turnstile if real spam gets through (see the design
// doc's follow-ups).
func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		return strings.TrimSpace(strings.Split(xff, ",")[0])
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
