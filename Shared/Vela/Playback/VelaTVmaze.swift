//
// Vela additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import Logging

/// Air dates and series status from TVmaze (https://www.tvmaze.com/api), which needs no API key.
/// Jellyfin only knows "Continuing" or "Ended" and nothing about episodes that are not in the library.
enum VelaTVmaze {

    private static let base = URL(string: "https://api.tvmaze.com")!
    private static let logger = Logger.swiftfin()

    /// Finds the show by the series' TVDB or IMDb ID and loads its episodes and seasons.
    static func show(providerIDs: [String: String]) async -> VelaTVmazeShow? {
        let lookups: [(String, String)] = [("thetvdb", "Tvdb"), ("imdb", "Imdb")].compactMap { query, key in
            providerIDs[key].map { (query, $0) }
        }

        for (query, id) in lookups {
            guard var components = URLComponents(url: base.appending(path: "lookup/shows"), resolvingAgainstBaseURL: false)
            else { continue }
            components.queryItems = [URLQueryItem(name: query, value: id)]

            guard let lookupURL = components.url,
                  let found: VelaTVmazeShow = await fetch(lookupURL)
            else { continue }

            var showComponents = URLComponents(url: base.appending(path: "shows/\(found.id)"), resolvingAgainstBaseURL: false)
            showComponents?.queryItems = [
                URLQueryItem(name: "embed[]", value: "episodes"),
                URLQueryItem(name: "embed[]", value: "seasons"),
            ]

            if let showURL = showComponents?.url, let show: VelaTVmazeShow = await fetch(showURL) {
                return show
            }
        }

        return nil
    }

    private static func fetch<T: Decodable>(_ url: URL) async -> T? {
        do {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.warning("TVmaze request failed: \(error.localizedDescription)")
            return nil
        }
    }
}
