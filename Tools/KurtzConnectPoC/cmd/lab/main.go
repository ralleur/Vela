// SPDX-License-Identifier: MPL-2.0
// LOCAL LAB ONLY: auto-approving test controller and test-certificate DERP.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/coder/websocket"
	"tailscale.com/derp/derpserver"
	"tailscale.com/net/netns"
	"tailscale.com/net/stun"
	"tailscale.com/tailcfg"
	"tailscale.com/tsnet"
	"tailscale.com/tstest/integration/testcontrol"
	"tailscale.com/types/key"
	"tailscale.com/types/logger"
	"kurtz.local/connect-poc/internal/gateway"
)

type zeroReader struct{}

func (zeroReader) ReadAt(b []byte, _ int64) (int, error) { clear(b); return len(b), nil }

func main() {
	upstream := flag.String("jellyfin", "", "loopback-only disposable Jellyfin origin")
	state := flag.String("state", "", "temporary private directory")
	output := flag.String("output", "", "private ready JSON path")
	flag.Parse()
	u, err := url.Parse(*upstream)
	if err != nil || u.Scheme != "http" || u.Hostname() != "127.0.0.1" || u.User != nil {
		log.Fatal("lab requires a disposable loopback Jellyfin server")
	}
	if *state == "" || *output == "" {
		log.Fatal("state/output required")
	}
	netns.SetEnabled(false)
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	d := derpserver.New(key.NewNode(), logger.Discard)
	defer d.Close()
	ds := httptest.NewUnstartedServer(derpserver.Handler(d))
	ds.Config.ErrorLog = log.New(io.Discard, "", 0)
	ds.StartTLS() // loopback only, self-signed; test map opts in below
	defer ds.Close()
	udp, err := net.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		log.Fatal(err)
	}
	defer udp.Close()
	go func() {
		b := make([]byte, 65536)
		for {
			n, addr, err := udp.ReadFromUDPAddrPort(b)
			if err != nil {
				return
			}
			tx, err := stun.ParseBindingRequest(b[:n])
			if err == nil {
				udp.WriteToUDPAddrPort(stun.Response(tx, addr), addr)
			}
		}
	}()
	dm := &tailcfg.DERPMap{Regions: map[int]*tailcfg.DERPRegion{1: {
		RegionID: 1, RegionCode: "local-lab", RegionName: "LOCAL TEST ONLY",
		Nodes: []*tailcfg.DERPNode{{Name: "local", RegionID: 1, HostName: "127.0.0.1",
			IPv4: "127.0.0.1", IPv6: "none", STUNPort: udp.LocalAddr().(*net.UDPAddr).Port,
			STUNTestIP: "127.0.0.1", DERPPort: ds.Listener.Addr().(*net.TCPAddr).Port,
			InsecureForTests: true}},
	}}}
	control := &testcontrol.Server{DERPMap: dm, Logf: logger.Discard}
	cs := httptest.NewUnstartedServer(control)
	control.HTTPTestServer = cs
	cs.Start()
	defer cs.Close()
	n := &tsnet.Server{Hostname: "kurtz-jellyfin-lab", Dir: *state,
		ControlURL: cs.URL, Logf: logger.Discard, UserLogf: logger.Discard}
	defer n.Close()
	upCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	if _, err := n.Up(upCtx); err != nil {
		log.Fatal(err)
	}
	ln, err := n.Listen("tcp", ":8443")
	if err != nil {
		log.Fatal(err)
	}
	ip, _ := n.TailscaleIPs()
	mux := http.NewServeMux()
	mux.HandleFunc("/__lab/bytes", func(w http.ResponseWriter, r *http.Request) {
		http.ServeContent(w, r, "bytes.bin", time.Unix(1, 0), io.NewSectionReader(zeroReader{}, 0, 32<<20))
	})
	mux.HandleFunc("/__lab/redirect", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "http://example.invalid/do-not-follow", http.StatusFound)
	})
	mux.HandleFunc("/__lab/echo", func(w http.ResponseWriter, r *http.Request) {
		c, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer c.CloseNow()
		ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
		defer cancel()
		t, b, err := c.Read(ctx)
		if err == nil {
			c.Write(ctx, t, b)
		}
	})
	mux.Handle("/", gateway.Handler(u, http.DefaultTransport, "", "/"))
	h := gateway.Server(mux)
	defer h.Close()
	go h.Serve(ln)
	// Same HTTP handler without encryption is the explicitly local baseline.
	local := httptest.NewServer(mux)
	defer local.Close()
	ready, _ := json.Marshal(map[string]string{"controlURL": cs.URL,
		"peerURL": fmt.Sprintf("http://%s:8443", ip), "lanURL": local.URL + "/"})
	if err := os.WriteFile(*output, ready, 0600); err != nil {
		log.Fatal(err)
	}
	<-ctx.Done()
}
