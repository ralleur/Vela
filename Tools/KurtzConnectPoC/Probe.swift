import AVFoundation

// SPDX-License-Identifier: MPL-2.0
// Native macOS probe. Intentionally independent of kurtz's production targets.
import Foundation

struct ProbeError: Error, CustomStringConvertible {
    let description: String
    init(_ text: String) {
        description = text
    }
}

@main
struct Probe {
    static func take(_ p: UnsafeMutablePointer<CChar>?) throws -> [String: Any] {
        guard let p else { throw ProbeError("empty C response") }
        defer { VCFree(p) }
        let object = try JSONSerialization.jsonObject(with: Data(String(cString: p).utf8))
        guard let result = object as? [String: Any] else { throw ProbeError("invalid C response") }
        if let error = result["error"] as? String {
            throw ProbeError(error)
        }
        return result
    }

    @MainActor
    static func main() async {
        do { try await run() }
        catch {
            // Avoid dumping URLSession errors: they can contain credentialed URLs.
            let message = (error as? ProbeError)?.description ?? "probe failed (details redacted)"
            print(String(data: try! JSONSerialization.data(withJSONObject: ["failed": message]), encoding: .utf8)!)
            exit(1)
        }
    }

    @MainActor
    static func run() async throws {
        guard CommandLine.arguments.count == 5 else {
            throw ProbeError("usage: probe ready.json credentials.json state-dir local-baseline|direct-peer|derp-relay")
        }
        let args = CommandLine.arguments
        func read(_ path: String) throws -> [String: String] {
            try JSONDecoder().decode([String: String].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        }
        let ready = try read(args[1])
        let credentials = try read(args[2])
        let expected = args[4]
        var result: [String: Any] = [
            "native": "macOS-arm64",
            "expectedRoute": expected,
            "scope": "local lab; not WAN or physical Apple TV"
        ]
        let base: URL
        if expected == "local-baseline" {
            base = URL(string: ready["lanURL"]!)!
        } else {
            let started = try ready["controlURL"]!.withCString { control in
                try args[3].withCString { state in
                    try ready["peerURL"]!.withCString { peer in
                        // cgo declares char*; VCStart only copies these inputs.
                        try take(VCStart(
                            UnsafeMutablePointer(mutating: control),
                            UnsafeMutablePointer(mutating: state),
                            UnsafeMutablePointer(mutating: peer)
                        ))
                    }
                }
            }
            base = URL(string: started["baseURL"] as! String)!
        }
        defer {
            if expected != "local-baseline" {
                VCStop()
            }
        }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 45
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        func request(
            _ path: String,
            method: String = "GET",
            body: [String: String]? = nil,
            token: String? = nil,
            range: String? = nil
        ) async throws -> (Data, HTTPURLResponse) {
            var req = URLRequest(url: URL(string: path, relativeTo: base)!.absoluteURL)
            req.httpMethod = method
            var auth = "MediaBrowser Client=\"KurtzConnectPoC\", Device=\"Local Lab\", DeviceId=\"kurtz-connect-disposable\", Version=\"0\""
            if let token {
                auth += ", Token=\"\(token)\""
            }
            req.setValue(auth, forHTTPHeaderField: "Authorization")
            if let body {
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            if let range {
                req.setValue(range, forHTTPHeaderField: "Range")
            }
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw ProbeError("non-HTTP response") }
            return (data, http)
        }
        func object(_ data: Data) throws -> [String: Any] {
            guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ProbeError("expected JSON object")
            }
            return value
        }
        let began = Date()
        let (publicData, publicHTTP) = try await request("System/Info/Public")
        let info = try object(publicData)
        guard publicHTTP.statusCode == 200, info["Id"] as? String == credentials["serverID"] else {
            throw ProbeError("real Jellyfin public-info identity mismatch")
        }
        result["publicInfoMs"] = Date().timeIntervalSince(began) * 1000
        result["jellyfinVersion"] = info["Version"]
        if expected != "local-baseline" {
            var path: [String: Any] = [:]
            for _ in 0 ..< 15 {
                path = try take(VCStatus())
                if path["route"] as? String == expected {
                    break
                }
                try await Task.sleep(for: .milliseconds(200))
            }
            guard path["route"] as? String == expected else { throw ProbeError("did not establish expected route") }
            result["before"] = path
        }
        let (authData, authHTTP) = try await request(
            "Users/AuthenticateByName",
            method: "POST",
            body: ["Username": credentials["username"]!, "Pw": credentials["password"]!]
        )
        let auth = try object(authData)
        guard authHTTP.statusCode == 200, let token = auth["AccessToken"] as? String,
              let user = auth["User"] as? [String: Any], let userID = user["Id"] as? String
        else {
            throw ProbeError("Jellyfin authentication failed")
        }
        result["authenticated"] = true
        let (itemsData, itemsHTTP) = try await request("Items?UserId=\(userID)&Recursive=true&IncludeItemTypes=Movie", token: token)
        let library = try object(itemsData)
        guard itemsHTTP.statusCode == 200, let items = library["Items"] as? [[String: Any]],
              let itemID = items.first?["Id"] as? String else { throw ProbeError("test video missing from library") }
        result["libraryItems"] = items.count
        let (rangeData, rangeHTTP) = try await request("Videos/\(itemID)/stream?static=true", token: token, range: "bytes=0-1023")
        guard rangeHTTP.statusCode == 206, rangeData.count == 1024 else { throw ProbeError("real video Range failed") }
        result["videoRange206"] = true

        // Native URLSession WebSocket exercises the bridge upgrade path; the echo
        // fixture is not Jellyfin's application-level socket/session protocol.
        var wsURL = URLComponents(url: URL(string: "__lab/echo", relativeTo: base)!.absoluteURL, resolvingAgainstBaseURL: false)!
        wsURL.scheme = "ws"
        let ws = session.webSocketTask(with: wsURL.url!)
        ws.resume()
        try await ws.send(.string("kurtz-connect-poc"))
        guard case .string("kurtz-connect-poc") = try await ws.receive() else { throw ProbeError("WebSocket echo failed") }
        ws.cancel(with: .normalClosure, reason: nil)
        result["webSocketEcho"] = true

        if expected != "local-baseline" {
            // Missing capability and browser-origin access must be rejected.
            var noCapability = URLComponents(url: base, resolvingAgainstBaseURL: false)!
            noCapability.path = "/System/Info/Public"
            let (_, denied) = try await session.data(from: noCapability.url!)
            guard (denied as? HTTPURLResponse)?.statusCode == 403 else { throw ProbeError("capability rejection failed") }
            var browser = URLRequest(url: URL(string: "System/Info/Public", relativeTo: base)!)
            browser.setValue("https://example.invalid", forHTTPHeaderField: "Origin")
            let (_, originDenied) = try await session.data(for: browser)
            guard (originDenied as? HTTPURLResponse)?.statusCode == 403 else { throw ProbeError("Origin rejection failed") }
            let (_, redirectDenied) = try await request("__lab/redirect")
            guard redirectDenied.statusCode == 502 else { throw ProbeError("redirect rejection failed") }
            result["negativeChecks"] = ["missing capability", "foreign Origin", "off-origin redirect"]
        }

        // Buffered test on purpose: report total-process memory, not transport-only.
        var speeds: [Double] = []
        for _ in 0 ..< 3 {
            let start = DispatchTime.now().uptimeNanoseconds
            let (data, response) = try await request("__lab/bytes")
            guard response.statusCode == 200, data.count == 32 << 20 else { throw ProbeError("bulk transfer failed") }
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
            speeds.append(Double(data.count) * 8 / elapsed / 1_000_000)
        }
        result["bulk32MiB_Mbps"] = speeds

        // Actual Jellyfin static MP4, streamed into AVPlayer. No UI/sound.
        var video = URLComponents(
            url: URL(string: "Videos/\(itemID)/stream", relativeTo: base)!.absoluteURL,
            resolvingAgainstBaseURL: false
        )!
        video.queryItems = [URLQueryItem(name: "static", value: "true"), URLQueryItem(name: "ApiKey", value: token)]
        let player = AVPlayer(url: video.url!)
        player.isMuted = true
        player.play()
        for _ in 0 ..< 100 {
            if player.currentTime().seconds > 0.5 {
                break
            }
            if player.currentItem?.status == .failed {
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        let seconds = player.currentTime().seconds
        player.pause()
        player.replaceCurrentItem(with: nil)
        guard seconds > 0.5 else { throw ProbeError("native AVPlayer did not advance") }
        result["avPlayerAdvancedSeconds"] = seconds
        if expected != "local-baseline" {
            let path = try take(VCStatus())
            guard path["route"] as? String == expected else { throw ProbeError("route changed during test") }
            result["after"] = path
        }
        try print(String(data: JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
    }
}
