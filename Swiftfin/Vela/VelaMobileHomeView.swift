// Vela additions, licensed under the Mozilla Public License 2.0.
#if !targetEnvironment(macCatalyst)
import Defaults
import FactoryKit
import SwiftUI

/// The local library is available with or without a Jellyfin session.
struct VelaMobileHomeView: View {
    @ObservedObject
    private var files = VelaLocalFiles.shared
    @InjectedObject(\.userSessionManager)
    private var sessions
    @State
    private var showServers = false
    @State
    private var showSettings = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image("VelaWatermark")
                        .resizable().scaledToFit().frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                    Text(VelaStrings.text("Your videos. Your library."))
                        .font(.title2.bold())
                    Text(VelaStrings.text("Open a video from Files, or watch from your Jellyfin server."))
                        .foregroundStyle(.secondary)
                    Button {
                        files.showPicker(subtitle: false)
                    } label: {
                        Label(VelaStrings.text("Open Video…"), systemImage: "folder")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("vela.open-video")
                    Text(VelaStrings.text("No account needed for local videos."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section(VelaStrings.text("Recently Opened")) {
                if files.recent.isEmpty {
                    Text(VelaStrings.text("Videos you open appear here when history is enabled."))
                        .foregroundStyle(.secondary)
                }
                ForEach(files.recent) { entry in
                    Button { files.reopen(entry) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.rectangle").foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.url.lastPathComponent).lineLimit(2)
                                if entry.position > 5 {
                                    Text(Duration.seconds(entry.position), format: .minuteSecondsNarrow)
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(VelaStrings.text("Start Over")) {
                            files.savePosition(.zero, duration: nil, for: entry.url)
                            files.reopen(entry)
                        }
                        Button(VelaStrings.text("Remove from Recent"), role: .destructive) {
                            files.removeRecent(entry)
                        }
                    }
                    .swipeActions {
                        Button(VelaStrings.text("Remove from Recent"), role: .destructive) {
                            files.removeRecent(entry)
                        }
                    }
                }
            }

            if sessions.currentSession == nil {
                Section(VelaStrings.text("Jellyfin")) {
                    Button { showServers = true } label: {
                        Label(VelaStrings.text("Connect Jellyfin"), systemImage: "server.rack")
                    }
                }
            }
        }
        .navigationTitle("Vela")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Label(VelaStrings.text("Settings"), systemImage: "gearshape")
                }
                .accessibilityIdentifier("vela.settings")
            }
        }
        .sheet(isPresented: $showSettings) { VelaMobileSettingsView() }
        .sheet(isPresented: $showServers) {
            NavigationInjectionView(coordinator: .init()) { SelectUserView() }
        }
    }
}

struct VelaMobileSettingsView: View {
    @Environment(\.dismiss)
    private var dismiss
    @AppStorage("vela.local.history")
    private var history = true
    @AppStorage("vela.local.engine")
    private var engine = "automatic"
    @AppStorage("vela.quick.enabled")
    private var presets = true
    @AppStorage("vela.subtitle.encoding")
    private var encoding = ""
    @Default(.VideoPlayer.jumpBackwardInterval)
    private var backward
    @Default(.VideoPlayer.jumpForwardInterval)
    private var forward
    @Default(.VideoPlayer.Subtitle.configuration)
    private var subtitleConfiguration
    @State
    private var showNotices = false
    @State
    private var confirmClear = false

    var body: some View {
        NavigationStack {
            Form {
                Section(VelaStrings.text("Local History")) {
                    Toggle(VelaStrings.text("Remember Recent Videos and Positions"), isOn: $history)
                    Text(VelaStrings
                        .text("History stays on this device. Turning this off clears saved files, positions and track choices."))
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(VelaStrings.text("Clear History"), role: .destructive) { confirmClear = true }
                }
                Section(VelaStrings.text("Playback")) {
                    Toggle(VelaStrings.text("Show Audio and Subtitle Presets"), isOn: $presets)
                    JumpIntervalPicker(title: VelaStrings.text("Skip Backward"), selection: $backward)
                    JumpIntervalPicker(title: VelaStrings.text("Skip Forward"), selection: $forward)
                    Picker(VelaStrings.text("Text Subtitle Size (VLC)"), selection: $subtitleConfiguration.size) {
                        Text(VelaStrings.text("Small")).tag(13)
                        Text(VelaStrings.text("Standard")).tag(9)
                        Text(VelaStrings.text("Large")).tag(4)
                    }
                }
                Section(VelaStrings.text("Playback Compatibility")) {
                    Picker(VelaStrings.text("Preferred Player"), selection: $engine) {
                        Text(VelaStrings.text("Automatic")).tag("automatic")
                        Text(VelaStrings.text("Alternative — mpv")).tag("mpv")
                    }
                    Text(VelaStrings.text("The default uses VLC. If a video fails, Try Compatible Playback offers the alternative once."))
                        .font(.footnote).foregroundStyle(.secondary)
                    Picker(VelaStrings.text("Subtitle Text Encoding"), selection: $encoding) {
                        Text(VelaStrings.text("Automatic")).tag("")
                        Text(verbatim: "UTF-8").tag("UTF-8")
                        Text(verbatim: "Windows-1252").tag("Windows-1252")
                        Text(verbatim: "ISO-8859-1").tag("ISO-8859-1")
                        Text(verbatim: "Shift_JIS").tag("Shift_JIS")
                    }
                    Text(VelaStrings.text("Change only if subtitle characters look wrong. Reopen the video after changing this."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section(VelaStrings.text("Privacy")) {
                    Text(VelaStrings.text("Local playback needs no account. No ads, subscriptions or analytics."))
                    Button(VelaStrings.text("Open Source Notices")) { showNotices = true }
                    Link(VelaStrings.text("Source Code"), destination: URL(string: "https://github.com/ralleur/Vela")!)
                    Link(VelaStrings.text("Privacy"), destination: URL(string: "https://ralleur.github.io/Vela/privacy.html")!)
                    Text(VelaStrings.text("Built on Swiftfin. An independent app by Ralleur."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(VelaStrings.text("Settings"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(VelaStrings.text("Done")) { dismiss() }
                }
            }
            .confirmationDialog(VelaStrings.text("Clear History"), isPresented: $confirmClear, titleVisibility: .visible) {
                Button(VelaStrings.text("Clear History"), role: .destructive) { VelaLocalFiles.shared.clearRecent() }
            } message: {
                Text(VelaStrings.text("This removes saved positions and track choices. Your video files are kept."))
            }
            .sheet(isPresented: $showNotices) { VelaNoticesView() }
            .onChange(of: history) {
                if !history {
                    VelaLocalFiles.shared.clearRecent()
                }
            }
        }
    }
}
#endif
