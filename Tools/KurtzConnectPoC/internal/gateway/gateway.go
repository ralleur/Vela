// SPDX-License-Identifier: MPL-2.0
// Disposable research code; not a production media proxy.
package gateway

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"time"
)

func Capability() string {
	var b [32]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic(err)
	}
	return hex.EncodeToString(b[:])
}

// Handler only forwards to target. It does not expose CONNECT or a caller-chosen
// destination. Prefix is an ephemeral capability; never log it or its URLs.
func Handler(target *url.URL, transport http.RoundTripper, host, prefix string) http.Handler {
	p := &httputil.ReverseProxy{
		Transport:     transport,
		FlushInterval: -1,
		Rewrite: func(r *httputil.ProxyRequest) {
			r.SetURL(target)
			r.Out.Host = target.Host
			r.Out.Header.Del("Origin")
			// Never trust caller-supplied forwarding metadata. Production must
			// synthesize verified remote identity with Jellyfin KnownProxies;
			// this local lab does not test Jellyfin's remote/local policy.
			r.Out.Header.Del("X-Forwarded-For")
			r.Out.Header.Del("X-Forwarded-Host")
			r.Out.Header.Del("X-Forwarded-Proto")
			r.Out.Header.Del("Forwarded")
		},
		ModifyResponse: func(r *http.Response) error {
			if r.Header.Get("Location") != "" {
				// Fail closed in this PoC. Production must handle vetted same-origin
				// redirects/base paths without leaking Jellyfin tokens.
				return errors.New("redirects unsupported in research bridge")
			}
			return nil
		},
		ErrorHandler: func(w http.ResponseWriter, _ *http.Request, _ error) {
			http.Error(w, "upstream unavailable or unsupported redirect", http.StatusBadGateway)
		},
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if (host != "" && r.Host != host) || r.Method == http.MethodConnect ||
			r.URL.IsAbs() || r.Header.Get("Origin") != "" || !strings.HasPrefix(r.URL.Path, prefix) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		r2 := r.Clone(r.Context())
		u := *r.URL
		u.Path = "/" + strings.TrimPrefix(r.URL.Path, prefix)
		u.RawPath = ""
		r2.URL = &u
		p.ServeHTTP(w, r2)
	})
}

func Server(h http.Handler) *http.Server {
	return &http.Server{Handler: h, ReadHeaderTimeout: 5 * time.Second,
		IdleTimeout: 30 * time.Second, MaxHeaderBytes: 32 << 10}
}
