// Vela additions, licensed under the Mozilla Public License 2.0.
#if targetEnvironment(macCatalyst)
import Defaults
import SwiftUI
import PreferencesView

enum VelaSettings {
    static let open = Notification.Name("VelaOpenSettings")
    static let languages = [("", "System"), ("de", "Deutsch"), ("en", "English"), ("fr", "Français"), ("es", "Español"), ("it", "Italiano"), ("nl", "Nederlands"), ("ja", "日本語")]
}

struct VelaSettingsHost: ViewModifier {
    @State private var presented = false
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: VelaSettings.open)) { _ in presented = true }
            .sheet(isPresented: $presented) { VelaSettingsView() }
            .keyCommands {
                KeyCommandAction(title: "Einstellungen …", input: ",", modifierFlags: .command) { presented = true }
            }
    }
}

struct VelaSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Default(.Vela.Mac.showPlayerWindowTitle) private var logo
    @Default(.VideoPlayer.jumpBackwardInterval) private var backward
    @Default(.VideoPlayer.jumpForwardInterval) private var forward
    @StoredValue(.User.previewImageScrubbing) private var previewImages: PreviewImageScrubbingOption
    @AppStorage("vela.language") private var language = ""
    @AppStorage("vela.quick.enabled") private var quickEnabled = true
    @AppStorage("vela.quick.custom") private var custom = false
    @AppStorage("vela.quick.audio.0") private var audio0 = "en"
    @AppStorage("vela.quick.audio.1") private var audio1 = "en"
    @AppStorage("vela.quick.audio.2") private var audio2 = "app"
    @AppStorage("vela.quick.subtitle.0") private var subtitle0 = "en"
    @AppStorage("vela.quick.subtitle.1") private var subtitle1 = "app"
    @AppStorage("vela.quick.subtitle.2") private var subtitle2 = "off"
    @State private var section = "Allgemein"
    @AppStorage("vela.shortcuts") private var shortcuts = "{}"
    @State private var recording: String?
    @State private var conflict: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image("VelaWatermark").resizable().scaledToFit().frame(width: 32, height: 32)
                Text("Einstellungen").font(.title2.weight(.semibold))
                Spacer()
                Button("Fertig") { dismiss() }.keyboardShortcut(.defaultAction)
            }.padding(24)
            Picker("Bereich", selection: $section) {
                ForEach(["Allgemein", "Wiedergabe", "Schnellzugriff", "Tastatur"], id: \.self) { Text($0) }
            }.pickerStyle(.segmented).padding(.horizontal, 24).padding(.bottom, 16)
            Divider()
            Form {
                switch section {
                case "Allgemein":
                    Section("Darstellung") {
                        Toggle("Vela-Logo im Fenster", isOn: $logo)
                        Text("Halbtransparent oben links. Im Vollbild wird das Logo immer ausgeblendet.").foregroundStyle(.secondary)
                    }
                    Section("Sprache") {
                        Picker("App-Sprache", selection: $language) {
                            ForEach(VelaSettings.languages, id: \.0) { Text($0.1).tag($0.0) }
                        }
                        Text("Die Oberfläche übernimmt die Sprache nach einem Neustart. System folgt deiner macOS-Sprache.").foregroundStyle(.secondary)
                    }
                case "Wiedergabe":
                    Section("Sprungweiten") {
                        JumpIntervalPicker(title: "Zurückspringen", selection: $backward)
                        JumpIntervalPicker(title: "Vorspringen", selection: $forward)
                        Text("Gilt unabhängig für die beiden Player-Buttons und die Pfeiltasten.").foregroundStyle(.secondary)
                    }
                    Section("Zeitleiste") {
                        Picker(L10n.previewImage, selection: $previewImages) {
                            Text("Trickplay").tag(PreviewImageScrubbingOption.trickplay(fallbackToChapters: false))
                            Text("Trickplay oder Kapitelbilder").tag(PreviewImageScrubbingOption.trickplay(fallbackToChapters: true))
                            Text(L10n.chapters).tag(PreviewImageScrubbingOption.chapters)
                            Text(L10n.disabled).tag(PreviewImageScrubbingOption.disabled)
                        }
                        Text("Beim Darüberfahren erscheint die Zielzeit. Vorschaubilder benötigen passende Bilder vom Server; Änderungen gelten ab dem nächsten Videostart.").foregroundStyle(.secondary)
                    }
                case "Schnellzugriff":
                    Section {
                        Toggle("Audio- und Untertitelbuttons anzeigen", isOn: $quickEnabled)
                        Toggle("Eigene Kombinationen", isOn: $custom).disabled(!quickEnabled)
                        Text("Es werden nur Kombinationen angezeigt, deren Spuren im Video vorhanden sind.").foregroundStyle(.secondary)
                    }
                    if custom && quickEnabled {
                        preset("Erster Button", audio: $audio0, subtitle: $subtitle0)
                        preset("Zweiter Button", audio: $audio1, subtitle: $subtitle1)
                        preset("Dritter Button", audio: $audio2, subtitle: $subtitle2)
                    }
                default:
                    Section {
                        Text("VLC für Mac als Ausgangspunkt. Klicke eine Belegung an und drücke die gewünschte Kombination.").foregroundStyle(.secondary)
                        if let conflict { Text(conflict).foregroundStyle(.red) }
                        ForEach(VelaShortcut.actions) { action in
                            HStack {
                                Text(action.title)
                                Spacer()
                                Button(recording == action.id ? "Tasten drücken …" : action.binding(in: shortcuts).label) {
                                    recording = action.id
                                    conflict = nil
                                }.buttonStyle(.bordered).monospaced()
                            }
                        }
                        Button("VLC-Belegung wiederherstellen") { shortcuts = "{}"; recording = nil }
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
                    } else if binding.flags == UIKeyModifierFlags.command.rawValue && [",", "q", "w", "h"].contains(binding.input) {
                        conflict = "Diese Kombination ist für macOS reserviert."
                    } else if let other = VelaShortcut.actions.first(where: { $0.id != recording && $0.binding(in: shortcuts) == binding }) {
                        conflict = "Bereits belegt: \(other.title)"
                    } else {
                        var values = VelaShortcut.decode(shortcuts)
                        values[recording] = binding
                        if let data = try? JSONEncoder().encode(values), let json = String(data: data, encoding: .utf8) { shortcuts = json }
                        self.recording = nil
                    }
                }.frame(width: 1, height: 1)
            }
        }
        .onChange(of: language) {
            if language.isEmpty { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
            else { UserDefaults.standard.set([language], forKey: "AppleLanguages") }
        }
    }

    private func preset(_ title: String, audio: Binding<String>, subtitle: Binding<String>) -> some View {
        Section(title) {
            languagePicker("Ton", value: audio, subtitles: false)
            languagePicker("Untertitel", value: subtitle, subtitles: true)
        }
    }

    private func languagePicker(_ title: String, value: Binding<String>, subtitles: Bool) -> some View {
        Picker(title, selection: value) {
            Text("App-Sprache").tag("app")
            if subtitles { Text("Aus").tag("off") }
            ForEach(VelaSettings.languages.filter { !$0.0.isEmpty }, id: \.0) { Text($0.1).tag($0.0) }
        }
    }
}

struct VelaShortcutRecorder: UIViewRepresentable {
    var receive: (VelaShortcut.Binding) -> Void
    func makeUIView(context: Context) -> Recorder { let view = Recorder(); view.receive = receive; return view }
    func updateUIView(_ view: Recorder, context: Context) {
        view.receive = receive
        DispatchQueue.main.async { view.becomeFirstResponder() }
    }
    final class Recorder: UIView {
        var receive: ((VelaShortcut.Binding) -> Void)?
        override var canBecomeFirstResponder: Bool { true }
        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            guard let key = presses.first?.key, !key.charactersIgnoringModifiers.isEmpty else { return }
            receive?(.init(input: key.charactersIgnoringModifiers.lowercased(), flags: key.modifierFlags.intersection([.command, .shift, .control, .alternate]).rawValue))
        }
    }
}
#endif
