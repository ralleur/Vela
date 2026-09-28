//
// Vela additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import JellyfinAPI

/// Compares Jellyfin language tags, so that "ger", "deu" and "de" all mean German.
enum VelaLanguage {

    static let english = "eng"
    static let german = "deu"

    /// ISO 639-2/B codes (what Jellyfin usually reports) mapped to their 639-2/T form.
    private static let bibliographicToTerminologic: [String: String] = [
        "alb": "sqi", "arm": "hye", "baq": "eus", "bur": "mya", "chi": "zho",
        "cze": "ces", "dut": "nld", "fre": "fra", "geo": "kat", "ger": "deu",
        "gre": "ell", "ice": "isl", "mac": "mkd", "mao": "mri", "may": "msa",
        "per": "fas", "rum": "ron", "slo": "slk", "tib": "bod", "wel": "cym",
    ]

    /// Returns a comparable three-letter code, or `nil` for missing and undetermined languages.
    static func normalize(_ tag: String?) -> String? {
        guard let tag else { return nil }

        let lowered = tag.trimmingCharacters(in: .whitespaces).lowercased()
        guard let primary = lowered.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init),
              primary.isNotEmpty,
              !["und", "mul", "zxx", "mis"].contains(primary)
        else { return nil }

        if primary.count == 2, let alpha3 = Locale.LanguageCode(primary).identifier(.alpha3) {
            return bibliographicToTerminologic[alpha3] ?? alpha3
        }

        return bibliographicToTerminologic[primary] ?? primary
    }

    static func matches(_ stream: MediaStream, language: String) -> Bool {
        normalize(stream.language) == normalize(language)
    }
}

extension MediaStream {

    /// Commentary tracks share the film's language, so they must never win a language match.
    var velaIsCommentary: Bool {
        let text = [title, displayTitle].compactMap { $0?.lowercased() }.joined(separator: " ")
        return text.contains("comment") || text.contains("kommentar")
    }
}

extension Sequence<MediaStream> {

    /// The best audio track in a language: no commentary, then the default track, then the most channels.
    func velaBestAudio(language: String) -> MediaStream? {
        filter { $0.type == .audio && VelaLanguage.matches($0, language: language) }
            .min { lhs, rhs in
                lhs.velaAudioRank.lexicographicallyPrecedes(rhs.velaAudioRank)
            }
    }

    /// The best subtitle track in a language, preferring the remembered forced/SDH flags.
    ///
    /// The flags are preferences, not requirements: a film with only SDH English subtitles
    /// still gets English subtitles.
    func velaBestSubtitle(
        language: String,
        isForced: Bool = false,
        isHearingImpaired: Bool = false
    ) -> MediaStream? {
        filter { $0.type == .subtitle && VelaLanguage.matches($0, language: language) }
            .min { lhs, rhs in
                lhs.velaSubtitleRank(isForced: isForced, isHearingImpaired: isHearingImpaired)
                    .lexicographicallyPrecedes(rhs.velaSubtitleRank(isForced: isForced, isHearingImpaired: isHearingImpaired))
            }
    }
}

private extension MediaStream {

    var velaAudioRank: [Int] {
        [
            velaIsCommentary ? 1 : 0,
            isDefault == true ? 0 : 1,
            -(channels ?? 0),
            index ?? .max,
        ]
    }

    func velaSubtitleRank(isForced: Bool, isHearingImpaired: Bool) -> [Int] {
        [
            (self.isForced ?? false) == isForced ? 0 : 1,
            (self.isHearingImpaired ?? false) == isHearingImpaired ? 0 : 1,
            velaIsCommentary ? 1 : 0,
            isDefault == true ? 0 : 1,
            index ?? .max,
        ]
    }
}

