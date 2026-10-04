// SPDX-License-Identifier: MPL-2.0
package gateway

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func TestDestinationAndCredentialBoundary(t *testing.T) {
	var seen int
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen++
		if r.Header.Get("Forwarded") != "" || r.Header.Get("X-Forwarded-For") != "" {
			t.Error("forwarded trust headers leaked")
		}
		if r.URL.Path == "/redirect" {
			w.Header().Set("Location", "http://example.invalid")
			w.WriteHeader(302)
			return
		}
		w.WriteHeader(204)
	}))
	defer upstream.Close()
	u, _ := url.Parse(upstream.URL)
	h := Handler(u, http.DefaultTransport, "127.0.0.1:12345", "/secret/")
	for _, tc := range []struct {
		method, path, host, origin string
		want                       int
	}{
		{"GET", "/secret/System/Info/Public", "127.0.0.1:12345", "", 204},
		{"GET", "/System/Info/Public", "127.0.0.1:12345", "", 403},
		{"GET", "/secret/System/Info/Public", "evil.invalid", "", 403},
		{"GET", "/secret/System/Info/Public", "127.0.0.1:12345", "https://evil.invalid", 403},
		{"CONNECT", "/secret/example.invalid", "127.0.0.1:12345", "", 403},
		{"GET", "http://example.invalid/secret/", "127.0.0.1:12345", "", 403},
		{"GET", "/secret/redirect", "127.0.0.1:12345", "", 502},
	} {
		r := httptest.NewRequest(tc.method, tc.path, nil)
		r.Host = tc.host
		r.Header.Set("Origin", tc.origin)
		r.Header.Set("Forwarded", "for=trusted")
		r.Header.Set("X-Forwarded-For", "127.0.0.1")
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		if w.Code != tc.want {
			t.Errorf("%s %s got %d want %d", tc.method, tc.path, w.Code, tc.want)
		}
		if strings.Contains(w.Body.String(), "secret") {
			t.Error("error exposed capability")
		}
	}
	if seen != 2 {
		t.Errorf("denied requests reached upstream: saw %d requests", seen)
	}
}
