// Vela additions, licensed under the Mozilla Public License 2.0.
#if targetEnvironment(macCatalyst)
import Defaults
import PreferencesView
import SwiftUI
import SwiftVLC

struct VelaShortcut: Identifiable {
    struct Binding: Codable, Equatable {
        var input: String
        var flags: Int
        var label: String {
            let modifiers = UIKeyModifierFlags(rawValue: flags)
            let prefix = (modifiers.contains(.control) ? "⌃" : "")
                + (modifiers.contains(.alternate) ? "⌥" : "")
                + (modifiers.contains(.shift) ? "⇧" : "")
                + (modifiers.contains(.command) ? "⌘" : "")
            let names = [" ": "Leertaste", "\r": "↩", UIKeyCommand.inputEscape: "⎋",
                         UIKeyCommand.inputLeftArrow: "←", UIKeyCommand.inputRightArrow: "→",
                         UIKeyCommand.inputUpArrow: "↑", UIKeyCommand.inputDownArrow: "↓"]
            return prefix + (names[input] ?? input.uppercased())
        }
    }
    let id: String
    let title: String
    let initial: Binding
    init(_ id: String, _ title: String, _ input: String, _ flags: UIKeyModifierFlags = []) {
        self.id = id; self.title = title; initial = Binding(input: input, flags: flags.rawValue)
    }
    func binding(in json: String) -> Binding { Self.decode(json)[id] ?? initial }
    static func decode(_ json: String) -> [String: Binding] {
        (try? JSONDecoder().decode([String: Binding].self, from: Data(json.utf8))) ?? [:]
    }
    // VideoLAN VLC 3.0.x src/libvlc-module.c, macOS defaults.
    static let actions: [Self] = [
        .init("play", "Wiedergabe / Pause", " "),
        .init("full", "Vollbild", "f", .command),
        .init("escape", "Vollbild verlassen", UIKeyCommand.inputEscape),
        .init("back", "Zurückspringen", UIKeyCommand.inputLeftArrow),
        .init("forward", "Vorspringen", UIKeyCommand.inputRightArrow),
        .init("next", "Nächster Titel", UIKeyCommand.inputRightArrow, .command),
        .init("previous", "Vorheriger Titel", UIKeyCommand.inputLeftArrow, .command),
        .init("stop", "Wiedergabe beenden", ".", .command),
        .init("faster", "Schneller", "=", .command),
        .init("slower", "Langsamer", "-", .command),
        .init("normal", "Normale Geschwindigkeit", "\\", .command),
        .init("back3", "3 Sekunden zurück", UIKeyCommand.inputLeftArrow, [.command, .control]),
        .init("forward3", "3 Sekunden vor", UIKeyCommand.inputRightArrow, [.command, .control]),
        .init("back10", "10 Sekunden zurück", UIKeyCommand.inputLeftArrow, [.command, .alternate]),
        .init("forward10", "10 Sekunden vor", UIKeyCommand.inputRightArrow, [.command, .alternate]),
        .init("back60", "1 Minute zurück", UIKeyCommand.inputLeftArrow, [.command, .shift]),
        .init("forward60", "1 Minute vor", UIKeyCommand.inputRightArrow, [.command, .shift]),
        .init("back300", "5 Minuten zurück", UIKeyCommand.inputLeftArrow, [.command, .shift, .alternate]),
        .init("forward300", "5 Minuten vor", UIKeyCommand.inputRightArrow, [.command, .shift, .alternate]),
        .init("volumeUp", "Lauter", UIKeyCommand.inputUpArrow, .command),
        .init("volumeDown", "Leiser", UIKeyCommand.inputDownArrow, .command),
        .init("mute", "Stumm", UIKeyCommand.inputDownArrow, [.command, .alternate]),
        .init("audio", "Nächste Tonspur", "l"),
        .init("subtitle", "Nächste Untertitelspur", "s"),
        .init("subtitlePrevious", "Vorherige Untertitelspur", "s", .alternate),
        .init("subtitleToggle", "Untertitel ein / aus", "s", .shift),
        .init("audioLater", "Ton 50 ms später", "g"),
        .init("audioEarlier", "Ton 50 ms früher", "f"),
        .init("subtitleLater", "Untertitel 50 ms später", "j"),
        .init("subtitleEarlier", "Untertitel 50 ms früher", "h"),
        .init("frame", "Nächstes Einzelbild", "e"),
        .init("position", "Bedienelemente anzeigen", "t"),
        .init("controls", "Bedienelemente ein / aus", "i"),
        .init("aspect", "Bild ausfüllen", "a"),
        .init("prompt", "Intro überspringen / Hinweis ausführen", "\r"),
    ]
}

struct VelaMacKeyCommands: ViewModifier {
    @EnvironmentObject private var manager: MediaPlayerManager
    @EnvironmentObject private var containerState: VideoPlayerContainerState
    @Router private var router
    @AppStorage("vela.shortcuts") private var shortcuts = "{}"
    @State private var audioOffset: Duration = .zero
    @State private var subtitleOffset: Duration = .zero
    @State private var rememberedSubtitle: Int?
    func body(content: Content) -> some View {
        content.keyCommands {
            for action in VelaShortcut.actions {
                KeyCommandAction(title: action.title, input: action.binding(in: shortcuts).input,
                                 modifierFlags: .init(rawValue: action.binding(in: shortcuts).flags)) {
                    perform(action.id)
                }
            }
        }
    }
    private func perform(_ id: String) {
        switch id {
        case "play": manager.togglePlayPause()
        case "full": VelaMiniPlayer.toggleFullScreen()
        case "escape": VelaMiniPlayer.leaveFullScreen()
        case "stop": manager.stop(); router.dismiss()
        case "back": manager.proxy?.jumpBackward(Defaults[.VideoPlayer.jumpBackwardInterval].rawValue)
        case "forward": manager.proxy?.jumpForward(Defaults[.VideoPlayer.jumpForwardInterval].rawValue)
        case "next": if let item = manager.queue?.nextItem { manager.playNewItem(provider: item) }
        case "previous": if let item = manager.queue?.previousItem { manager.playNewItem(provider: item) }
        case "faster": manager.setRate(rate: min(4, manager.rate + 0.25))
        case "slower": manager.setRate(rate: max(0.25, manager.rate - 0.25))
        case "normal": manager.setRate(rate: 1)
        case "position": containerState.isPresentingOverlay = true
        case "controls": containerState.isPresentingOverlay.toggle()
        case "aspect": containerState.isAspectFilled.toggle()
        case "prompt": VelaPlaybackPrompts.shared.performPrompt()
        case "audio":
            guard let item = manager.playbackItem, !item.audioStreams.isEmpty else { return }
            let indexes = item.audioStreams.compactMap(\.index)
            guard !indexes.isEmpty else { return }
            let next = ((indexes.firstIndex(of: item.selectedAudioStreamIndex ?? -1) ?? -1) + 1) % indexes.count
            item.selectedAudioStreamIndex = indexes[next]
        case "subtitle", "subtitlePrevious", "subtitleToggle":
            guard let item = manager.playbackItem else { return }
            let indexes = [-1] + item.subtitleStreams.compactMap(\.index)
            let current = item.selectedSubtitleStreamIndex ?? -1
            if id == "subtitleToggle" {
                if current >= 0 { rememberedSubtitle = current; item.selectedSubtitleStreamIndex = -1 }
                else { item.selectedSubtitleStreamIndex = rememberedSubtitle ?? indexes.last ?? -1 }
            } else {
                let delta = id == "subtitlePrevious" ? indexes.count - 1 : 1
                item.selectedSubtitleStreamIndex = indexes[((indexes.firstIndex(of: current) ?? 0) + delta) % indexes.count]
            }
        case "audioLater", "audioEarlier":
            audioOffset += .milliseconds(id == "audioLater" ? 50 : -50)
            (manager.proxy as? any MediaPlayerOffsetConfigurable)?.setAudioOffset(audioOffset)
        case "subtitleLater", "subtitleEarlier":
            subtitleOffset += .milliseconds(id == "subtitleLater" ? 50 : -50)
            (manager.proxy as? any MediaPlayerOffsetConfigurable)?.setSubtitleOffset(subtitleOffset)
        case "volumeUp", "volumeDown", "mute", "frame":
            guard let proxy = manager.proxy as? VLCMediaPlayerProxy else { return }
            if id == "mute" { proxy.player.isMuted.toggle() }
            else if id == "frame" { manager.setPlaybackRequestStatus(status: .paused); proxy.player.nextFrame() }
            else { try? proxy.player.setAudioVolume(Volume(proxy.player.volume + (id == "volumeUp" ? 0.05 : -0.05))) }
        default:
            if id.hasPrefix("back"), let value = Int(id.dropFirst(4)) { manager.proxy?.jumpBackward(.seconds(value)) }
            if id.hasPrefix("forward"), let value = Int(id.dropFirst(7)) { manager.proxy?.jumpForward(.seconds(value)) }
        }
    }
}
#endif
