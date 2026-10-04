//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// kurtz additions, licensed under the Mozilla Public License 2.0.
#if targetEnvironment(macCatalyst)
import Defaults
import PreferencesView
import SwiftUI

enum KurtzSettings {
    static let open = Notification.Name("KurtzOpenSettings")
    static func present() {
        guard var presenter = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else { return }
        while let next = presenter.presentedViewController {
            presenter = next
        }
        guard !(presenter is KurtzSettingsController) else { return }
        let controller = KurtzSettingsController()
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

private final class KurtzSettingsController: UIHostingController<KurtzSettingsView> {
    init() {
        super.init(rootView: KurtzSettingsView())
        rootView.close = { [weak self] in self?.dismiss(animated: true) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}

struct KurtzSettingsHost: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: KurtzSettings.open)) { _ in KurtzSettings.present() }
            .keyCommands {
                KeyCommandAction(title: KurtzStrings.text("Settings…"), input: ",", modifierFlags: .command) { KurtzSettings.present() }
            }
    }
}

struct KurtzSettingsView: View {
    var close: (() -> Void)?
    @Environment(\.dismiss)
    private var dismiss
    @Default(.Kurtz.Mac.showPlayerWindowTitle)
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
                Image("KurtzWatermark").resizable().scaledToFit().frame(width: 32, height: 32).accessibilityHidden(true)
                Text(KurtzStrings.text("Settings")).font(KurtzBrand.heading(22, relativeTo: .title2))
                Spacer()
                Button(KurtzStrings.text("Done")) {
                    if let close {
                        close()
                    } else {
                        dismiss()
                    }
                }.keyboardShortcut(.defaultAction)
            }.padding(24)
            Picker(KurtzStrings.text("Section"), selection: $section) {
                ForEach(["General", "Playback", "Presets", "Keyboard", "Advanced"], id: \.self) { Text(KurtzStrings.text($0)) }
            }.pickerStyle(.segmented).padding(.horizontal, 24).padding(.bottom, 16)
            Divider()
            Form {
                switch section {
                case "General":
                    Section(KurtzStrings.text("Appearance")) {
                        Toggle(KurtzStrings.text("kurtz Logo in Window"), isOn: $logo)
                        Text(KurtzStrings.text("Translucent at the top left. Always hidden in fullscreen.")).foregroundStyle(.secondary)
                    }
                    Section(KurtzStrings.text("Language")) {
                        Picker(KurtzStrings.text("App Language"), selection: $language) {
                            ForEach(KurtzSettings.languages, id: \.0) { Text($0.1).tag($0.0) }
                        }
                        Text(KurtzStrings.text("Language changes apply after restarting. System follows your macOS language."))
                            .foregroundStyle(.secondary)
                    }
                    Section(KurtzStrings.text("Local History")) {
                        Toggle(KurtzStrings.text("Remember Recent Videos and Positions"), isOn: $history)
                        Text(KurtzStrings
                            .text("History stays on this Mac. Turning this off clears saved files, positions and track choices."))
                            .foregroundStyle(.secondary)
                        Button(KurtzStrings.text("Clear History")) { KurtzLocalFiles.shared.clearRecent() }
                    }
                    Section(KurtzStrings.text("Privacy")) {
                        Text(KurtzStrings.text("Local playback needs no account. No ads, subscriptions or analytics."))
                            .foregroundStyle(.secondary)
                        Button(KurtzStrings.text("Open Source Notices")) { showNotices = true }
                    }
                case "Playback":
                    Section(KurtzStrings.text("Seeking")) {
                        JumpIntervalPicker(title: KurtzStrings.text("Skip Backward"), selection: $backward)
                        JumpIntervalPicker(title: KurtzStrings.text("Skip Forward"), selection: $forward)
                        Text(KurtzStrings.text("Applies to the player buttons and arrow keys.")).foregroundStyle(.secondary)
                    }
                    Section(KurtzStrings.text("Timeline")) {
                        Picker(L10n.previewImage, selection: $previewImages) {
                            Text(KurtzStrings.text("Preview Images")).tag(PreviewImageScrubbingOption.trickplay(fallbackToChapters: false))
                            Text(KurtzStrings.text("Preview Images or Chapter Images"))
                                .tag(PreviewImageScrubbingOption.trickplay(fallbackToChapters: true))
                            Text(L10n.chapters).tag(PreviewImageScrubbingOption.chapters)
                            Text(L10n.disabled).tag(PreviewImageScrubbingOption.disabled)
                        }
                        Text(KurtzStrings
                            .text(
                                "Hover to see the target time. Preview images require server-provided artwork. Changes apply to the next video."
                            ))
                            .foregroundStyle(.secondary)
                    }
                    Section(KurtzStrings.text("Subtitles")) {
                        Picker(KurtzStrings.text("Text Subtitle Size (VLC)"), selection: $subtitleConfiguration.size) {
                            Text(KurtzStrings.text("Small")).tag(13)
                            Text(KurtzStrings.text("Standard")).tag(9)
                            Text(KurtzStrings.text("Large")).tag(4)
                        }
                        Text(KurtzStrings
                            .text(
                                "Styled ASS subtitles may retain their own appearance. mpv text captions follow macOS accessibility settings."
                            ))
                            .foregroundStyle(.secondary)
                    }
                case "Presets":
                    Section {
                        Toggle(KurtzStrings.text("Show Audio and Subtitle Presets"), isOn: $quickEnabled)
                        Toggle(KurtzStrings.text("Custom Combinations"), isOn: $custom).disabled(!quickEnabled)
                        Text(KurtzStrings.text("Only combinations with available tracks are shown.")).foregroundStyle(.secondary)
                    }
                    if custom && quickEnabled {
                        preset("First Button", audio: $audio0, subtitle: $subtitle0)
                        preset("Second Button", audio: $audio1, subtitle: $subtitle1)
                        preset("Third Button", audio: $audio2, subtitle: $subtitle2)
                    }
                case "Advanced":
                    Section(KurtzStrings.text("Playback Compatibility")) {
                        Picker(KurtzStrings.text("Preferred Player"), selection: $localEngine) {
                            Text(KurtzStrings.text("Automatic")).tag("automatic")
                            Text(KurtzStrings.text("Alternative — mpv")).tag("mpv")
                        }
                        Text(KurtzStrings
                            .text("The default uses VLC. If a video fails, Try Compatible Playback offers the alternative once."))
                            .foregroundStyle(.secondary)
                    }
                    Section(KurtzStrings.text("Subtitle Text Encoding")) {
                        Picker(KurtzStrings.text("Subtitle Text Encoding"), selection: $encoding) {
                            Text(KurtzStrings.text("Automatic")).tag("")
                            Text(KurtzStrings.text("UTF-8")).tag("UTF-8")
                            Text(KurtzStrings.text("Western (Windows-1252)")).tag("Windows-1252")
                            Text(KurtzStrings.text("Western (ISO-8859-1)")).tag("ISO-8859-1")
                            Text(KurtzStrings.text("Japanese (Shift_JIS)")).tag("Shift_JIS")
                        }
                        Text(KurtzStrings.text("Change only if subtitle characters look wrong. Reopen the video after changing this."))
                            .foregroundStyle(.secondary)
                    }
                default:
                    Section {
                        Text(KurtzStrings.text("Click a shortcut and press your preferred key combination.")).foregroundStyle(.secondary)
                        if let conflict {
                            Text(conflict).foregroundStyle(.red)
                        }
                        ForEach(KurtzShortcut.actions) { action in
                            HStack {
                                Text(action.title)
                                Spacer()
                                Button(recording == action.id ? KurtzStrings.text("Press Keys…") : action.binding(in: shortcuts).label) {
                                    recording = action.id
                                    conflict = nil
                                }.buttonStyle(.bordered).monospaced()
                            }
                        }
                        Button(KurtzStrings.text("Restore Default Shortcuts")) { shortcuts = "{}"
                            recording = nil
                        }
                    }
                }
            }.formStyle(.grouped)
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 510, idealHeight: 600)
        .background {
            if let recording {
                KurtzShortcutRecorder { binding in
                    if binding.input == UIKeyCommand.inputEscape && binding.flags == 0 {
                        self.recording = nil
                    } else if (binding.flags & UIKeyModifierFlags.command.rawValue != 0 && [",", "q", "w", "h", "o"]
                        .contains(binding.input)) ||
                        (binding.input == "p" && binding.flags == UIKeyModifierFlags.command.union(.alternate).rawValue)
                    {
                        conflict = KurtzStrings.text("This shortcut is reserved by macOS.")
                    } else if let other = KurtzShortcut.actions
                        .first(where: { $0.id != recording && $0.binding(in: shortcuts) == binding })
                    {
                        conflict = "\(KurtzStrings.text("Already assigned")): \(other.title)"
                    } else {
                        var values = KurtzShortcut.decode(shortcuts)
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
        .tint(KurtzBrand.yellow)
        .sheet(isPresented: $showNotices) { KurtzNoticesView(close: { showNotices = false }) }
        .onChange(of: history) {
            if !history {
                KurtzLocalFiles.shared.clearRecent()
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
        Section(KurtzStrings.text(title)) {
            languagePicker(KurtzStrings.text("Audio"), value: audio, subtitles: false)
            languagePicker(KurtzStrings.text("Subtitles"), value: subtitle, subtitles: true)
        }
    }

    private func languagePicker(_ title: String, value: Binding<String>, subtitles: Bool) -> some View {
        Picker(title, selection: value) {
            Text(KurtzStrings.text("App Language")).tag("app")
            if subtitles {
                Text(KurtzStrings.text("Off")).tag("off")
            }
            ForEach(KurtzSettings.languages.filter { !$0.0.isEmpty }, id: \.0) { Text($0.1).tag($0.0) }
        }
    }
}

struct KurtzShortcutRecorder: UIViewRepresentable {
    var receive: (KurtzShortcut.Binding) -> Void
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
        var receive: ((KurtzShortcut.Binding) -> Void)?
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
