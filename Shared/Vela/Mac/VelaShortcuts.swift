//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

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
            let names = [
                " ": VelaStrings.text("Space"),
                "\r": "↩",
                UIKeyCommand.inputEscape: "⎋",
                UIKeyCommand.inputLeftArrow: "←",
                UIKeyCommand.inputRightArrow: "→",
                UIKeyCommand.inputUpArrow: "↑",
                UIKeyCommand.inputDownArrow: "↓"
            ]
            return prefix + (names[input] ?? input.uppercased())
        }
    }

    let id: String
    let title: String
    let initial: Binding
    init(_ id: String, _ title: String, _ input: String, _ flags: UIKeyModifierFlags = []) {
        self.id = id
        self.title = VelaStrings.text(title)
        initial = Binding(input: input, flags: flags.rawValue)
    }

    func binding(in json: String) -> Binding {
        Self.decode(json)[id] ?? initial
    }

    static func decode(_ json: String) -> [String: Binding] {
        (try? JSONDecoder().decode([String: Binding].self, from: Data(json.utf8))) ?? [:]
    }

    // VideoLAN VLC 3.0.x src/libvlc-module.c, macOS defaults.
    static let actions: [Self] = [
        .init("play", "Play / Pause", " "),
        .init("full", "Fullscreen", "f", .command),
        .init("escape", "Exit Fullscreen", UIKeyCommand.inputEscape),
        .init("back", "Skip Backward", UIKeyCommand.inputLeftArrow),
        .init("forward", "Skip Forward", UIKeyCommand.inputRightArrow),
        .init("next", "Next Item", UIKeyCommand.inputRightArrow, .command),
        .init("previous", "Previous Item", UIKeyCommand.inputLeftArrow, .command),
        .init("stop", "Stop Playback", ".", .command),
        .init("faster", "Faster", "=", .command),
        .init("slower", "Slower", "-", .command),
        .init("normal", "Normal Speed", "\\", .command),
        .init("back3", "Back 3 Seconds", UIKeyCommand.inputLeftArrow, [.command, .control]),
        .init("forward3", "Forward 3 Seconds", UIKeyCommand.inputRightArrow, [.command, .control]),
        .init("back10", "Back 10 Seconds", UIKeyCommand.inputLeftArrow, [.command, .alternate]),
        .init("forward10", "Forward 10 Seconds", UIKeyCommand.inputRightArrow, [.command, .alternate]),
        .init("back60", "Back 1 Minute", UIKeyCommand.inputLeftArrow, [.command, .shift]),
        .init("forward60", "Forward 1 Minute", UIKeyCommand.inputRightArrow, [.command, .shift]),
        .init("back300", "Back 5 Minutes", UIKeyCommand.inputLeftArrow, [.command, .shift, .alternate]),
        .init("forward300", "Forward 5 Minutes", UIKeyCommand.inputRightArrow, [.command, .shift, .alternate]),
        .init("volumeUp", "Volume Up", UIKeyCommand.inputUpArrow, .command),
        .init("volumeDown", "Volume Down", UIKeyCommand.inputDownArrow, .command),
        .init("mute", "Mute", UIKeyCommand.inputDownArrow, [.command, .alternate]),
        .init("audio", "Next Audio Track", "l"),
        .init("subtitle", "Next Subtitle Track", "s"),
        .init("subtitlePrevious", "Previous Subtitle Track", "s", .alternate),
        .init("subtitleToggle", "Toggle Subtitles", "s", .shift),
        .init("audioLater", "Audio Later (50 ms)", "g"),
        .init("audioEarlier", "Audio Earlier (50 ms)", "f"),
        .init("subtitleLater", "Subtitles Later (50 ms)", "j"),
        .init("subtitleEarlier", "Subtitles Earlier (50 ms)", "h"),
        .init("frame", "Next Frame", "e"),
        .init("position", "Show Controls", "t"),
        .init("controls", "Toggle Controls", "i"),
        .init("aspect", "Fill Video", "a"),
        .init("prompt", "Skip Intro / Perform Prompt", "\r"),
    ]
}

struct VelaMacKeyCommands: ViewModifier {
    @EnvironmentObject
    private var manager: MediaPlayerManager
    @EnvironmentObject
    private var containerState: VideoPlayerContainerState
    @Router
    private var router
    @AppStorage("vela.shortcuts")
    private var shortcuts = "{}"
    @State
    private var rememberedSubtitle: Int?
    func body(content: Content) -> some View {
        content.keyCommands {
            KeyCommandAction(title: VelaStrings.text("Settings…"), input: ",", modifierFlags: .command) { VelaSettings.present() }
            for action in VelaShortcut.actions {
                KeyCommandAction(
                    title: action.title,
                    input: action.binding(in: shortcuts).input,
                    modifierFlags: .init(rawValue: action.binding(in: shortcuts).flags)
                ) {
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
        case "stop": manager.stop()
            if manager.onStop == nil {
                router.dismiss()
            }
        case "back": manager.proxy?.jumpBackward(Defaults[.VideoPlayer.jumpBackwardInterval].rawValue)
        case "forward": manager.proxy?.jumpForward(Defaults[.VideoPlayer.jumpForwardInterval].rawValue)
        case "next": if let item = manager.queue?.nextItem {
                manager.playNewItem(provider: item)
            }
        case "previous": if let item = manager.queue?.previousItem {
                manager.playNewItem(provider: item)
            }
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
                if current >= 0 {
                    rememberedSubtitle = current
                    item.selectedSubtitleStreamIndex = -1
                } else {
                    item.selectedSubtitleStreamIndex = rememberedSubtitle ?? indexes.last ?? -1
                }
            } else {
                let delta = id == "subtitlePrevious" ? indexes.count - 1 : 1
                item.selectedSubtitleStreamIndex = indexes[((indexes.firstIndex(of: current) ?? 0) + delta) % indexes.count]
            }
        case "audioLater", "audioEarlier":
            manager.audioOffset += .milliseconds(id == "audioLater" ? 50 : -50)
            containerState.toastProxy.present(String(format: "%+.2f s", manager.audioOffset.seconds), systemName: "speaker.wave.2")
        case "subtitleLater", "subtitleEarlier":
            manager.subtitleOffset += .milliseconds(id == "subtitleLater" ? 50 : -50)
            containerState.toastProxy.present(String(format: "%+.2f s", manager.subtitleOffset.seconds), systemName: "captions.bubble")
        case "volumeUp": manager.volume = min(1, manager.volume + 0.05)
        case "volumeDown": manager.volume = max(0, manager.volume - 0.05)
        case "mute": manager.isMuted.toggle()
        case "frame":
            guard let proxy = manager.proxy as? VLCMediaPlayerProxy else { return }
            manager.setPlaybackRequestStatus(status: .paused)
            proxy.player.nextFrame()
        default:
            if id.hasPrefix("back"), let value = Int(id.dropFirst(4)) {
                manager.proxy?.jumpBackward(.seconds(value))
            }
            if id.hasPrefix("forward"), let value = Int(id.dropFirst(7)) {
                manager.proxy?.jumpForward(.seconds(value))
            }
        }
    }
}
#endif
