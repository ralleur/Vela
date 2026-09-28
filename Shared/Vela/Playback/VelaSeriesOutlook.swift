//
// Vela additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation

/// The parts of a TVmaze show that tell what comes after an episode.
struct VelaTVmazeShow: Decodable {

    struct Episode: Decodable {
        let season: Int
        let number: Int?
        let airdate: String?
        let airstamp: String?
    }

    struct Season: Decodable {
        let number: Int
        let premiereDate: String?
    }

    struct Embedded: Decodable {
        let episodes: [Episode]?
        let seasons: [Season]?
    }

    let id: Int
    let status: String?
    let _embedded: Embedded?

    var episodes: [Episode] {
        _embedded?.episodes ?? []
    }

    var seasons: [Season] {
        _embedded?.seasons ?? []
    }
}

/// One sentence about what follows an episode when the library has nothing after it:
/// a date for the next episode or season, an announced season, or the end of the series.
enum VelaSeriesOutlook {

    static let title = "Keine weitere Folge in deiner Bibliothek"

    static func message(
        afterSeason season: Int,
        episode: Int,
        show: VelaTVmazeShow,
        now: Date = .now,
        timeZone: TimeZone = .current
    ) -> String {
        let following = show.episodes
            .compactMap { episode -> (season: Int, number: Int, episode: VelaTVmazeShow.Episode)? in
                guard let number = episode.number else { return nil }
                return (episode.season, number, episode)
            }
            .filter { $0.season > season || ($0.season == season && $0.number > episode) }
            .sorted { ($0.season, $0.number) < ($1.season, $1.number) }
            .first

        if let following {
            let code = "S\(following.season)E\(following.number)"
            let aired = airDate(following.episode, timeZone: timeZone)

            if let airstamp = following.episode.airstamp.flatMap(parseTimestamp), airstamp <= now {
                if let aired {
                    return "\(code) lief am \(format(aired, now: now, timeZone: timeZone, weekday: false)), ist aber noch nicht in deiner Bibliothek."
                }
                return "\(code) ist schon erschienen, aber noch nicht in deiner Bibliothek."
            }

            if following.season == season {
                if let aired {
                    return "Die nächste Folge (\(code)) kommt am \(format(aired, now: now, timeZone: timeZone, weekday: true))."
                }
                return "Die nächste Folge (\(code)) ist angekündigt, einen Termin gibt es noch nicht."
            }

            if let aired {
                return "Staffel \(following.season) startet am \(format(aired, now: now, timeZone: timeZone, weekday: false))."
            }
            return "Staffel \(following.season) ist angekündigt, einen Termin gibt es noch nicht."
        }

        if let next = show.seasons.filter({ $0.number > season }).min(by: { $0.number < $1.number }) {
            if let premiere = next.premiereDate.flatMap({ parseDay($0, timeZone: timeZone) }), premiere > now {
                return "Staffel \(next.number) startet am \(format(premiere, now: now, timeZone: timeZone, weekday: false))."
            }
            return "Staffel \(next.number) ist angekündigt, einen Termin gibt es noch nicht."
        }

        switch show.status {
        case "Ended":
            return "Die Serie ist beendet."
        case "In Development":
            return "Eine neue Staffel ist in Arbeit, einen Termin gibt es noch nicht."
        case "To Be Determined":
            return "Staffel \(season) ist zu Ende. Ob es weitergeht, ist noch offen."
        default:
            return "Staffel \(season) ist zu Ende. Eine neue Staffel ist noch nicht angekündigt."
        }
    }

    /// Without TVmaze data, Jellyfin's own status is all there is.
    static func fallbackMessage(jellyfinStatus: String?, season: Int?) -> String {
        if jellyfinStatus == "Ended" {
            return "Die Serie ist beendet."
        }
        if let season {
            return "Staffel \(season) ist zu Ende. Zur nächsten Folge gibt es noch keine Infos."
        }
        return "Zur nächsten Folge gibt es noch keine Infos."
    }

    // MARK: - Dates

    private static func airDate(_ episode: VelaTVmazeShow.Episode, timeZone: TimeZone) -> Date? {
        if let airstamp = episode.airstamp.flatMap(parseTimestamp) {
            return airstamp
        }
        return episode.airdate.flatMap { parseDay($0, timeZone: timeZone) }
    }

    private static func parseTimestamp(_ string: String) -> Date? {
        try? Date(string, strategy: .iso8601)
    }

    private static func parseDay(_ string: String, timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    /// "Montag, 5. Oktober", or "9. Juli 2027" outside the current year.
    private static func format(_ date: Date, now: Date, timeZone: TimeZone, weekday: Bool) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = timeZone

        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        formatter.dateFormat = switch (weekday, sameYear) {
        case (true, true): "EEEE, d. MMMM"
        case (true, false): "EEEE, d. MMMM yyyy"
        case (false, true): "d. MMMM"
        case (false, false): "d. MMMM yyyy"
        }

        return formatter.string(from: date)
    }
}
