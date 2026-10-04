#!/usr/bin/env python3
"""Disposable LOCAL lab. Never uses an existing Jellyfin/Tailscale account."""
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

HERE = Path(__file__).resolve().parent
IMAGE = "jellyfin/jellyfin:10.11.11"


def run(argv, **kwargs):
    return subprocess.run(argv, check=True, text=True, capture_output=True, **kwargs)


def main():
    os.umask(0o077)
    if not (HERE / "build/probe").exists():
        raise RuntimeError("Run bash build.sh first")
    name = "kurtz-connect-poc-" + secrets.token_hex(5)
    root = Path(tempfile.mkdtemp(prefix="kurtz-connect-poc-"))
    lab = None
    container_started = False
    network_created = False
    results = {"scope": "same Mac, loopback control/STUN/DERP; no WAN benchmark",
               "tailscale": "v1.102.5", "image": IMAGE, "runs": []}
    try:
        for directory in ("config", "cache", "media"):
            (root / directory).mkdir()
        run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i",
             "testsrc2=size=1280x720:rate=24", "-t", "6", "-c:v", "libx264",
             "-preset", "ultrafast", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
             str(root / "media/kurtz Connect Sample.mp4")])
        # Reuse an installed image; never silently pull/upgrade an existing server.
        results["imageID"] = run(["docker", "image", "inspect", IMAGE,
                                  "--format", "{{.Id}}"]).stdout.strip()
        run(["docker", "network", "create", "--label", "kurtz-connect-poc=true", name])
        network_created = True
        run(["docker", "run", "--rm", "--detach", "--name", name, "--network", name,
             "--label", "kurtz-connect-poc=true", "-p", "127.0.0.1::8096",
             "-v", str(root / "config") + ":/config",
             "-v", str(root / "cache") + ":/cache",
             "-v", str(root / "media") + ":/media:ro", IMAGE])
        container_started = True
        published = subprocess.run(["docker", "port", name, "8096/tcp"], text=True, capture_output=True)
        if published.returncode != 0:
            # Only this newly created container; its logs contain no credentials yet.
            details = subprocess.run(["docker", "logs", name], text=True, capture_output=True)
            raise RuntimeError("Disposable container startup: " + published.stderr + details.stderr[-1200:])
        port = published.stdout.strip().rsplit(":", 1)[1]
        origin = "http://127.0.0.1:" + port

        def api(path, method="GET", data=None, token=None):
            headers = {"Content-Type": "application/json",
                       "Authorization": 'MediaBrowser Client="KurtzConnectSetup", Device="Local", DeviceId="lab-setup", Version="0"'}
            if token:
                headers["X-Emby-Token"] = token
            req = urllib.request.Request(origin + path,
                                         data=None if data is None else json.dumps(data).encode(),
                                         headers=headers, method=method)
            with urllib.request.urlopen(req, timeout=3) as response:
                body = response.read()
                return json.loads(body) if body else None

        for _ in range(90):
            try:
                public = api("/System/Info/Public")
                api("/Startup/Configuration")  # public info is available earlier in startup
                break
            except (OSError, urllib.error.URLError):
                time.sleep(1)
        else:
            raise RuntimeError("Disposable Jellyfin did not start")
        username, password = "kurtz-lab", secrets.token_urlsafe(32)
        api("/Startup/Configuration", "POST", {"UICulture": "en-US", "MetadataCountryCode": "US",
                                              "PreferredMetadataLanguage": "en", "ServerName": "kurtz disposable lab"})
        api("/Startup/User")  # Jellyfin 10.11 initializes its first user here
        api("/Startup/User", "POST", {"Name": username, "Password": password})
        api("/Startup/RemoteAccess", "POST", {"EnableRemoteAccess": True, "EnableAutomaticPortMapping": False})
        api("/Startup/Complete", "POST", {})
        auth = api("/Users/AuthenticateByName", "POST", {"Username": username, "Pw": password})
        token = auth["AccessToken"]
        api("/Library/VirtualFolders?name=KurtzLab&collectionType=movies&refreshLibrary=true", "POST",
            {"LibraryOptions": {"PathInfos": [{"Path": "/media"}], "EnableRealtimeMonitor": False,
                                "TypeOptions": [{"Type": "Movie", "MetadataFetchers": [], "ImageFetchers": []}]}}, token)
        for _ in range(60):
            items = api("/Items?Recursive=true&IncludeItemTypes=Movie", token=token)
            if items.get("Items"):
                break
            time.sleep(1)
        else:
            raise RuntimeError("Disposable Jellyfin did not index the sample")
        credentials = root / "credentials.json"
        credentials.write_text(json.dumps({"username": username, "password": password,
                                          "serverID": public["Id"]}))
        for mode in ("local-baseline", "direct-peer", "derp-relay"):
            state = root / mode
            state.mkdir()
            client_state = state / "client"
            client_state.mkdir()
            server_state = state / "helper"
            server_state.mkdir()
            ready = state / "ready.json"
            env = dict(os.environ)
            for key in list(env):
                if key.startswith("TS_"):
                    del env[key]  # no ambient auth keys, control settings or debug flags
            env["TS_NO_LOGS_NO_SUPPORT"] = "true"
            env["TS_DISABLE_PORTMAPPER"] = "true"
            if mode == "derp-relay":
                env["TS_DEBUG_ALWAYS_USE_DERP"] = "true"
            with open(state / "lab.stderr", "w") as log:
                lab = subprocess.Popen([str(HERE / "build/lab"), "-jellyfin", origin,
                                        "-state", str(server_state), "-output", str(ready)],
                                       env=env, stdout=subprocess.DEVNULL, stderr=log)
            for _ in range(60):
                if ready.exists():
                    break
                if lab.poll() is not None:
                    raise RuntimeError("lab exited before readiness")
                time.sleep(0.5)
            else:
                raise RuntimeError("lab readiness timed out")
            start = time.monotonic()
            proc = subprocess.run(["/usr/bin/time", "-l", str(HERE / "build/probe"), str(ready),
                                   str(credentials), str(client_state), mode], env=env,
                                  text=True, capture_output=True, timeout=100)
            parsed = [json.loads(line) for line in proc.stdout.splitlines() if line.startswith("{")]
            if proc.returncode != 0 or not parsed or "failed" in parsed[-1]:
                # Probe emits only redacted failure summaries. Preserve no private state.
                raise RuntimeError("Native " + mode + " probe: " + str(parsed or proc.returncode))
            result = parsed[-1]
            result["processWallSeconds"] = time.monotonic() - start
            rss = re.search(r"(\d+)\s+maximum resident set size", proc.stderr)
            if rss:
                result["processPeakRSSBytes"] = int(rss.group(1))
            cpu = re.search(r"([\d.]+) real\s+([\d.]+) user\s+([\d.]+) sys", proc.stderr)
            if cpu:
                result["processCPUSeconds"] = float(cpu.group(2)) + float(cpu.group(3))
            results["runs"].append(result)
            print(mode + ": passed", flush=True)
            lab.terminate()
            try:
                lab.wait(timeout=8)
            except subprocess.TimeoutExpired:
                lab.kill(); lab.wait()
            lab = None
        (HERE / "runs").mkdir(exist_ok=True)
        path = HERE / "runs/results.json"
        path.write_text(json.dumps(results, indent=2) + "\n")
        print("Sanitized measurements: " + str(path))
    finally:
        if lab is not None:
            lab.terminate()
            try:
                lab.wait(timeout=5)
            except subprocess.TimeoutExpired:
                lab.kill(); lab.wait()
        if container_started:
            subprocess.run(["docker", "rm", "-f", name], capture_output=True)
        if network_created:
            subprocess.run(["docker", "network", "rm", name], capture_output=True)
        shutil.rmtree(root)


if __name__ == "__main__":
    main()
