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

enum VelaSettings {
    static let open = Notification.Name("VelaOpenSettings")
    static func present() {
        guard var presenter = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else { return }
        while let next = presenter.presentedViewController { presenter = next }
        guard !(presenter is VelaSettingsController) else { return }
        let controller = VelaSettingsController()
        controller.modalPresentationStyle = .formSheet
        controller.preferredContentSize = CGSize(width: 680, height: 680)
        presenter.present(controller, animated: true)
    }

    static let languages = [
        ("", "System"),
        ("de", "Deutsch"),
        ("en", "English"),
        ("fr", "Français"),
        ("es", "Español"),
        ("it", "Italiano"),
        ("nl", "Nederlands"),
        ("ja", "日本語")
    ]
}

private final class VelaSettingsController: UIHostingController<VelaSettingsView> {
    init() {
        super.init(rootView: VelaSettingsView())
        rootView.close = { [weak self] in self?.dismiss(animated: true) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

struct VelaSettingsHost: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: VelaSettings.open)) { _ in VelaSettings.present() }
            .keyCommands {
                KeyCommandAction(title: VelaStrings.text("Settings…"), input: ",", modifierFlags: .command) { VelaSettings.present() }
            }
    }
}

struct VelaSettingsView: View {
    var close: (() -> Void)? = nil
    @Environment(\.dismiss)
    private var dismiss
    @Default(.Vela.Mac.showPlayerWindowTitle)
    private var logo
    @Default(.VideoPlayer.jumpBackwardInterval)
    private var backward
    @Default(.VideoPlayer.jumpForwardInterval)
    private var forward
    @StoredValue(.User.previewImageScrubbing)
    private var previewImages: PreviewImageScrubbingOption
    @AppStorage("vela.language")
    private var language = ""
    @AppStorage("vela.quick.enabled")
    private var quickEnabled = true
    @AppStorage("vela.quick.custom")
    private var custom = false
    @AppStorage("vela.quick.audio.0")
    private var audio0 = "en"
    @AppStorage("vela.quick.audio.1")
    private var audio1 = "en"
    @AppStorage("vela.quick.audio.2")
    private var audio2 = "app"
    @AppStorage("vela.quick.subtitle.0")
    private var subtitle0 = "en"
    @AppStorage("vela.quick.subtitle.1")
    private var subtitle1 = "app"
    @AppStorage("vela.quick.subtitle.2")
    private var subtitle2 = "off"
    @AppStorage("vela.local.engine")
    private var localEngine = "automatic"
    @AppStorage("vela.local.history")
    private var history = true
    @AppStorage("vela.subtitle.encoding")
    private var encoding = ""
    @Default(.VideoPlayer.Subtitle.configuration)
    private var subtitleConfiguration
    @State
    private var section = "General"
    @AppStorage("vela.shortcuts")
    private var shortcuts = "{}"
    @State
    private var recording: String?
    @State
    private var conflict: String?
    @State
    private var showNotices = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image("VelaWatermark").resizable().scaledToFit().frame(width: 32, height: 32).accessibilityHidden(true)
                Text(VelaStrings.text("Settings")).font(.title2.weight(.semibold))
                Spacer()
                Button(VelaStrings.text("Done")) { if let close { close() } else { dismiss() } }.keyboardShortcut(.defaultAction)
            }.padding(24)
            Picker(VelaStrings.text("Section"), selection: $section) {
                ForEach(["General", "Playback", "Presets", "Keyboard", "Advanced"], id: \.self) { Text(VelaStrings.text($0)) }
            }.pickerStyle(.segmented).padding(.horizontal, 24).padding(.bottom, 16)
            Divider()
            Form {
                switch section {
                case "General":
                    Section(VelaStrings.text("Appearance")) {
                        Toggle(VelaStrings.text("Vela Logo in Window"), isOn: $logo)
                        Text(VelaStrings.text("Translucent at the top left. Always hidden in fullscreen.")).foregroundStyle(.secondary)
                    }
                    Section(VelaStrings.text("Language")) {
                        Picker(VelaStrings.text("App Language"), selection: $language) {
                            ForEach(VelaSettings.languages, id: \.0) { Text($0.1).tag($0.0) }
                        }
                        Text(VelaStrings.text("Language changes apply after restarting. System follows your macOS language."))
                            .foregroundStyle(.secondary)
                    }
                    Section(VelaStrings.text("Local History")) {
                        Toggle(VelaStrings.text("Remember Recent Videos and Positions"), isOn: $history)
                        Text(VelaStrings
                            .text("History stays on this Mac. Turning this off clears saved files, positions and track choices."))
                            .foregroundStyle(.secondary)
                        Button(VelaStrings.text("Clear History")) { VelaLocalFiles.shared.clearRecent() }
                    }
                    Section(VelaStrings.text("Privacy")) {
                        Text(VelaStrings.text("Local playback needs no account. No ads, subscriptions or analytics."))
                            .foregroundStyle(.secondary)
                        Button(VelaStrings.text("Open Source Notices")) { showNotices = true }
                    }
                case "Playback":
                    Section(VelaStrings.text("Seeking")) {
                        JumpIntervalPicker(title: VelaStrings.text("Skip Backward"), selection: $backward)
                        JumpIntervalPicker(title: VelaStrings.text("Skip Forward"), selection: $forward)
                        Text(VelaStrings.text("Applies to the player buttons and arrow keys.")).foregroundStyle(.secondary)
                    }
                    Section(VelaStrings.text("Timeline")) {
                        Picker(L10n.previewImage, selection: $previewImages) {
                            Text(VelaStrings.text("Preview Images")).tag(PreviewImageScrubbingOption.trickplay(fallbackToChapters: false))
                            Text(VelaStrings.text("Preview Images or Chapter Images"))
                                .tag(PreviewImageScrubbingOption.trickplay(fallbackToChapters: true))
                            Text(L10n.chapters).tag(PreviewImageScrubbingOption.chapters)
                            Text(L10n.disabled).tag(PreviewImageScrubbingOption.disabled)
                        }
                        Text(VelaStrings
                            .text(
                                "Hover to see the target time. Preview images require server-provided artwork. Changes apply to the next video."
                            ))
                            .foregroundStyle(.secondary)
                    }
                    Section(VelaStrings.text("Subtitles")) {
                        Picker(VelaStrings.text("Text Subtitle Size (VLC)"), selection: $subtitleConfiguration.size) {
                            Text(VelaStrings.text("Small")).tag(13)
                            Text(VelaStrings.text("Standard")).tag(9)
                            Text(VelaStrings.text("Large")).tag(4)
                        }
                        Text(VelaStrings
                            .text(
                                "Styled ASS subtitles may retain their own appearance. mpv text captions follow macOS accessibility settings."
                            ))
                            .foregroundStyle(.secondary)
                    }
                case "Presets":
                    Section {
                        Toggle(VelaStrings.text("Show Audio and Subtitle Presets"), isOn: $quickEnabled)
                        Toggle(VelaStrings.text("Custom Combinations"), isOn: $custom).disabled(!quickEnabled)
                        Text(VelaStrings.text("Only combinations with available tracks are shown.")).foregroundStyle(.secondary)
                    }
                    if custom && quickEnabled {
                        preset("First Button", audio: $audio0, subtitle: $subtitle0)
                        preset("Second Button", audio: $audio1, subtitle: $subtitle1)
                        preset("Third Button", audio: $audio2, subtitle: $subtitle2)
                    }
                case "Advanced":
                    Section(VelaStrings.text("Playback Compatibility")) {
                        Picker(VelaStrings.text("Preferred Player"), selection: $localEngine) {
                            Text(VelaStrings.text("Automatic")).tag("automatic")
                            Text(VelaStrings.text("Alternative — mpv")).tag("mpv")
                        }
                        Text(VelaStrings
                            .text("The default uses VLC. If a video fails, Try Compatible Playback offers the alternative once."))
                            .foregroundStyle(.secondary)
                    }
                    Section(VelaStrings.text("Subtitle Text Encoding")) {
                        Picker(VelaStrings.text("Subtitle Text Encoding"), selection: $encoding) {
                            Text(VelaStrings.text("Automatic")).tag("")
                            Text(VelaStrings.text("UTF-8")).tag("UTF-8")
                            Text(VelaStrings.text("Western (Windows-1252)")).tag("Windows-1252")
                            Text(VelaStrings.text("Western (ISO-8859-1)")).tag("ISO-8859-1")
                            Text(VelaStrings.text("Japanese (Shift_JIS)")).tag("Shift_JIS")
                        }
                        Text(VelaStrings.text("Change only if subtitle characters look wrong. Reopen the video after changing this."))
                            .foregroundStyle(.secondary)
                    }
                default:
                    Section {
                        Text(VelaStrings.text("Click a shortcut and press your preferred key combination.")).foregroundStyle(.secondary)
                        if let conflict {
                            Text(conflict).foregroundStyle(.red)
                        }
                        ForEach(VelaShortcut.actions) { action in
                            HStack {
                                Text(action.title)
                                Spacer()
                                Button(recording == action.id ? VelaStrings.text("Press Keys…") : action.binding(in: shortcuts).label) {
                                    recording = action.id
                                    conflict = nil
                                }.buttonStyle(.bordered).monospaced()
                            }
                        }
                        Button(VelaStrings.text("Restore Default Shortcuts")) { shortcuts = "{}"
                            recording = nil
                        }
                    }
                }
            }.formStyle(.grouped)
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 510, idealHeight: 600)
        .background {
            if let recording {
                VelaShortcutRecorder { binding in
                    if binding.input == UIKeyCommand.inputEscape && binding.flags == 0 {
                        self.recording = nil
                    } else if (binding.flags & UIKeyModifierFlags.command.rawValue != 0 && [",", "q", "w", "h", "o"]
                        .contains(binding.input)) ||
                        (binding.input == "p" && binding.flags == UIKeyModifierFlags.command.union(.alternate).rawValue)
                    {
                        conflict = VelaStrings.text("This shortcut is reserved by macOS.")
                    } else if let other = VelaShortcut.actions
                        .first(where: { $0.id != recording && $0.binding(in: shortcuts) == binding })
                    {
                        conflict = "\(VelaStrings.text("Already assigned")): \(other.title)"
                    } else {
                        var values = VelaShortcut.decode(shortcuts)
                        values[recording] = binding
                        if let data = try? JSONEncoder().encode(values), let json = String(data: data, encoding: .utf8) {
                            shortcuts = json
                        }
                        self.recording = nil
                    }
                }.frame(width: 1, height: 1)
            }
        }
        .onAppear {
            if localEngine == "vlc" {
                localEngine = "automatic"
            }
        }
        .sheet(isPresented: $showNotices) { VelaNoticesView(close: { showNotices = false }) }
        .onChange(of: history) {
            if !history {
                VelaLocalFiles.shared.clearRecent()
            }
        }
        .onChange(of: language) {
            if language.isEmpty {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set([language], forKey: "AppleLanguages")
            }
        }
    }

    private func preset(_ title: String, audio: Binding<String>, subtitle: Binding<String>) -> some View {
        Section(VelaStrings.text(title)) {
            languagePicker(VelaStrings.text("Audio"), value: audio, subtitles: false)
            languagePicker(VelaStrings.text("Subtitles"), value: subtitle, subtitles: true)
        }
    }

    private func languagePicker(_ title: String, value: Binding<String>, subtitles: Bool) -> some View {
        Picker(title, selection: value) {
            Text(VelaStrings.text("App Language")).tag("app")
            if subtitles {
                Text(VelaStrings.text("Off")).tag("off")
            }
            ForEach(VelaSettings.languages.filter { !$0.0.isEmpty }, id: \.0) { Text($0.1).tag($0.0) }
        }
    }
}

struct VelaShortcutRecorder: UIViewRepresentable {
    var receive: (VelaShortcut.Binding) -> Void
    func makeUIView(context: Context) -> Recorder {
        let view = Recorder()
        view.receive = receive
        return view
    }

    func updateUIView(_ view: Recorder, context: Context) {
        view.receive = receive
        DispatchQueue.main.async { view.becomeFirstResponder() }
    }

    final class Recorder: UIView {
        var receive: ((VelaShortcut.Binding) -> Void)?
        override var canBecomeFirstResponder: Bool {
            true
        }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            guard let key = presses.first?.key, !key.charactersIgnoringModifiers.isEmpty else { return }
            receive?(.init(
                input: key.charactersIgnoringModifiers.lowercased(),
                flags: key.modifierFlags.intersection([.command, .shift, .control, .alternate]).rawValue
            ))
        }
    }
}
#endif
