// SPDX-License-Identifier: MPL-2.0
// Test-only C ABI for an embedded, application-owned Tailscale node.
package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"sync"
	"time"
	"unsafe"

	"tailscale.com/net/netns"
	"tailscale.com/tailcfg"
	"tailscale.com/tsnet"
	"tailscale.com/types/logger"
	"kurtz.local/connect-poc/internal/gateway"
)

var mu sync.Mutex
var node *tsnet.Server
var server *http.Server
var transport *http.Transport
var peerIP netip.Addr

func result(v any) *C.char      { b, _ := json.Marshal(v); return C.CString(string(b)) }
func failure(err error) *C.char { return result(map[string]any{"error": err.Error()}) }

//export VCStart
func VCStart(control, state, peer *C.char) *C.char {
	mu.Lock()
	defer mu.Unlock()
	if node != nil {
		return failure(fmt.Errorf("already started"))
	}
	c, err := url.Parse(C.GoString(control))
	if err != nil || c.Scheme != "http" || c.Hostname() != "127.0.0.1" || c.User != nil {
		return failure(fmt.Errorf("research build only accepts loopback test control"))
	}
	target, err := url.Parse(C.GoString(peer))
	if err != nil || target.Scheme != "http" || target.User != nil {
		return failure(fmt.Errorf("invalid lab peer"))
	}
	ip, err := netip.ParseAddr(target.Hostname())
	if err != nil || !netip.MustParsePrefix("100.64.0.0/10").Contains(ip) {
		return failure(fmt.Errorf("expected lab tailnet IPv4 peer"))
	}
	peerIP = ip
	netns.SetEnabled(false) // upstream test pattern; never changes OS routes
	n := &tsnet.Server{Hostname: "kurtz-native-poc", Dir: C.GoString(state),
		ControlURL: c.String(), Logf: logger.Discard, UserLogf: logger.Discard}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if _, err := n.Up(ctx); err != nil {
		n.Close()
		return failure(err)
	}
	ln, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		n.Close()
		return failure(err)
	}
	transport = &http.Transport{DialContext: n.Dial, MaxIdleConns: 8,
		ResponseHeaderTimeout: 15 * time.Second, IdleConnTimeout: 30 * time.Second}
	prefix := "/" + gateway.Capability() + "/"
	server = gateway.Server(gateway.Handler(target, transport, ln.Addr().String(), prefix))
	node = n
	go server.Serve(ln)
	return result(map[string]any{"baseURL": "http://" + ln.Addr().String() + prefix})
}

//export VCStatus
func VCStatus() *C.char {
	mu.Lock()
	defer mu.Unlock()
	if node == nil {
		return failure(fmt.Errorf("node not started"))
	}
	lc, err := node.LocalClient()
	if err != nil {
		return failure(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	ping, err := lc.Ping(ctx, peerIP, tailcfg.PingDisco)
	if err != nil {
		return failure(err)
	}
	route := "unknown"
	if ping.Err == "" {
		switch {
		case ping.Endpoint != "":
			route = "direct-peer"
		case ping.PeerRelay != "":
			route = "peer-relay"
		case ping.DERPRegionID != 0:
			route = "derp-relay"
		}
	}
	out := map[string]any{"route": route, "probeLatencyMs": ping.LatencySeconds * 1000,
		"derpRegion": ping.DERPRegionCode}
	if st, err := lc.Status(ctx); err == nil {
		for _, p := range st.Peer {
			for _, ip := range p.TailscaleIPs {
				if ip == peerIP {
					out["rxBytes"] = p.RxBytes
					out["txBytes"] = p.TxBytes
					out["hasDirectEndpoint"] = p.CurAddr != ""
				}
			}
		}
	}
	return result(out)
}

//export VCStop
func VCStop() {
	mu.Lock()
	defer mu.Unlock()
	if server != nil {
		server.Close()
		server = nil
	}
	if transport != nil {
		transport.CloseIdleConnections()
		transport = nil
	}
	if node != nil {
		node.Close()
		node = nil
	}
}

//export VCFree
func VCFree(p *C.char) { C.free(unsafe.Pointer(p)) }

func main() {}
