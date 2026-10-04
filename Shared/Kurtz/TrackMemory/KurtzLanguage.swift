//
// kurtz additions to Swiftfin, subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import JellyfinAPI

/// Compares Jellyfin language tags, so that "ger", "deu" and "de" all mean German.
enum KurtzLanguage {

    static let english = "eng"
    static let german = "deu"

    /// The language selected for the app. Apple's per-app language setting is reflected in
    /// `preferredLocalizations`; on a German Mac this resolves to German by default.
    static var appLanguage: String {
        if let selected = UserDefaults.standard.string(forKey: "vela.language"),
           let normalized = normalize(selected)
        {
            return normalized
        }
        return preferredAppLanguage(
            preferredLocalizations: Bundle.main.preferredLocalizations,
            preferredLanguages: Locale.preferredLanguages
        )
    }

    static func preferredAppLanguage(
        preferredLocalizations: [String],
        preferredLanguages: [String]
    ) -> String {
        for identifier in preferredLocalizations + preferredLanguages {
            if let language = normalize(identifier) {
                return language
            }
        }

        return german
    }

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

    static func shortCode(_ language: String) -> String {
        guard let normalized = normalize(language) else { return language.uppercased() }

        return (Locale.LanguageCode(normalized).identifier(.alpha2) ?? normalized).uppercased()
    }
}

/// One-press audio and subtitle combinations for the player. English remains the
/// original-language choice while the app language replaces the former fixed German choice.
struct KurtzLanguagePreset: Identifiable, Equatable {

    let audioLanguage: String
    /// `nil` means subtitles off.
    let subtitleLanguage: String?
    let appLanguage: String

    var id: String {
        "\(audioLanguage):\(subtitleLanguage ?? "off")"
    }

    var title: String {
        let audio = KurtzLanguage.shortCode(audioLanguage)

        if let subtitleLanguage {
            return "\(audio) + \(KurtzLanguage.shortCode(subtitleLanguage)) \(subtitleAbbreviation)"
        }

        return "\(audio) \(withoutSubtitles)"
    }

    /// Short toolbar label; retain the full title for accessibility.
    var compactTitle: String {
        subtitleLanguage == nil ? KurtzLanguage.shortCode(audioLanguage) : title
    }

    static func presets(appLanguage: String) -> [Self] {
        let local = KurtzLanguage.normalize(appLanguage) ?? KurtzLanguage.german
        var presets = [
            Self(audioLanguage: KurtzLanguage.english, subtitleLanguage: KurtzLanguage.english, appLanguage: local),
        ]

        if local != KurtzLanguage.english {
            presets.append(Self(audioLanguage: KurtzLanguage.english, subtitleLanguage: local, appLanguage: local))
        }

        presets.append(Self(audioLanguage: local, subtitleLanguage: nil, appLanguage: local))
        return presets
    }

    /// The stream indexes for this preset, or `nil` when the item lacks a needed track.
    func streamIndexes(
        audioStreams: [MediaStream],
        subtitleStreams: [MediaStream]
    ) -> (audio: Int, subtitle: Int)? {
        guard let audio = audioStreams.kurtzBestAudio(language: audioLanguage)?.index else { return nil }

        guard let subtitleLanguage else {
            return (audio, -1)
        }

        // Forced subtitles only cover foreign-language parts, so they never count as
        // the full subtitle selection represented by these buttons.
        guard let subtitle = subtitleStreams
            .filter({ $0.isForced != true })
            .kurtzBestSubtitle(language: subtitleLanguage)?.index
        else { return nil }

        return (audio, subtitle)
    }

    /// No quick buttons at all are shown when the title has no full subtitle choice.
    static func availablePresets(
        appLanguage: String,
        audioStreams: [MediaStream],
        subtitleStreams: [MediaStream]
    ) -> [Self] {
        guard subtitleStreams.contains(where: { $0.isForced != true }) else { return [] }

        return presets(appLanguage: appLanguage).filter {
            $0.streamIndexes(audioStreams: audioStreams, subtitleStreams: subtitleStreams) != nil
        }
    }

    private var subtitleAbbreviation: String {
        switch KurtzLanguage.normalize(appLanguage) {
        case KurtzLanguage.german: "UT"
        case "fra": "ST"
        default: "SUB"
        }
    }

    private var withoutSubtitles: String {
        switch KurtzLanguage.normalize(appLanguage) {
        case KurtzLanguage.german: "ohne UT"
        case "fra": "sans ST"
        default: "no SUB"
        }
    }
}

extension MediaStream {

    /// Commentary tracks share the film's language, so they must never win a language match.
    var kurtzIsCommentary: Bool {
        let text = [title, displayTitle].compactMap { $0?.lowercased() }.joined(separator: " ")
        return text.contains("comment") || text.contains("kommentar")
    }
}

extension Sequence<MediaStream> {

    /// The best audio track in a language: no commentary, then the default track, then the most channels.
    func kurtzBestAudio(language: String) -> MediaStream? {
        filter { $0.type == .audio && KurtzLanguage.matches($0, language: language) }
            .min { lhs, rhs in
                lhs.kurtzAudioRank.lexicographicallyPrecedes(rhs.kurtzAudioRank)
            }
    }

    /// The best subtitle track in a language, preferring the remembered forced/SDH flags.
    ///
    /// The flags are preferences, not requirements: a film with only SDH English subtitles
    /// still gets English subtitles.
    func kurtzBestSubtitle(
        language: String,
        isForced: Bool = false,
        isHearingImpaired: Bool = false
    ) -> MediaStream? {
        filter { $0.type == .subtitle && KurtzLanguage.matches($0, language: language) }
            .min { lhs, rhs in
                lhs.kurtzSubtitleRank(isForced: isForced, isHearingImpaired: isHearingImpaired)
                    .lexicographicallyPrecedes(rhs.kurtzSubtitleRank(isForced: isForced, isHearingImpaired: isHearingImpaired))
            }
    }
}

private extension MediaStream {

    var kurtzAudioRank: [Int] {
        [
            kurtzIsCommentary ? 1 : 0,
            isDefault == true ? 0 : 1,
            -(channels ?? 0),
            index ?? .max,
        ]
    }

    func kurtzSubtitleRank(isForced: Bool, isHearingImpaired: Bool) -> [Int] {
        [
            (self.isForced ?? false) == isForced ? 0 : 1,
            (self.isHearingImpaired ?? false) == isHearingImpaired ? 0 : 1,
            kurtzIsCommentary ? 1 : 0,
            isDefault == true ? 0 : 1,
            index ?? .max,
        ]
    }
}
