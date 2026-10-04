// kurtz additions, licensed under the Mozilla Public License 2.0.
#if !targetEnvironment(macCatalyst)
import Defaults
import FactoryKit
import SwiftUI

/// The local library is available with or without a Jellyfin session.
struct KurtzMobileHomeView: View {
    @ObservedObject
    private var files = KurtzLocalFiles.shared
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
                    Image("KurtzWatermark")
                        .resizable().scaledToFit().frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                    Text(KurtzStrings.text("Your videos. Your library."))
                        .font(KurtzBrand.heading(22, relativeTo: .title2))
                    Text(KurtzStrings.text("Open a video from Files, or watch from your Jellyfin server."))
                        .foregroundStyle(.secondary)
                    Button {
                        files.showPicker(subtitle: false)
                    } label: {
                        Label(KurtzStrings.text("Open Video…"), systemImage: "folder")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(KurtzBrand.yellow)
                    .foregroundStyle(KurtzBrand.graphite)
                    .accessibilityIdentifier("kurtz.open-video")
                    Text(KurtzStrings.text("No account needed for local videos."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section(KurtzStrings.text("Recently Opened")) {
                if files.recent.isEmpty {
                    Text(KurtzStrings.text("Videos you open appear here when history is enabled."))
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
                        Button(KurtzStrings.text("Start Over")) {
                            files.savePosition(.zero, duration: nil, for: entry.url)
                            files.reopen(entry)
                        }
                        Button(KurtzStrings.text("Remove from Recent"), role: .destructive) {
                            files.removeRecent(entry)
                        }
                    }
                    .swipeActions {
                        Button(KurtzStrings.text("Remove from Recent"), role: .destructive) {
                            files.removeRecent(entry)
                        }
                    }
                }
            }

            if sessions.currentSession == nil {
                Section(KurtzStrings.text("Jellyfin")) {
                    Button { showServers = true } label: {
                        Label(KurtzStrings.text("Connect Jellyfin"), systemImage: "server.rack")
                    }
                }
            }
        }
        .navigationTitle("kurtz")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Label(KurtzStrings.text("Settings"), systemImage: "gearshape")
                }
                .accessibilityIdentifier("kurtz.settings")
            }
        }
        .sheet(isPresented: $showSettings) { KurtzMobileSettingsView() }
        .sheet(isPresented: $showServers) {
            NavigationInjectionView(coordinator: .init()) { SelectUserView() }
        }
    }
}

struct KurtzMobileSettingsView: View {
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
                Section(KurtzStrings.text("Local History")) {
                    Toggle(KurtzStrings.text("Remember Recent Videos and Positions"), isOn: $history)
                    Text(KurtzStrings
                        .text("History stays on this device. Turning this off clears saved files, positions and track choices."))
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(KurtzStrings.text("Clear History"), role: .destructive) { confirmClear = true }
                }
                Section(KurtzStrings.text("Playback")) {
                    Toggle(KurtzStrings.text("Show Audio and Subtitle Presets"), isOn: $presets)
                    JumpIntervalPicker(title: KurtzStrings.text("Skip Backward"), selection: $backward)
                    JumpIntervalPicker(title: KurtzStrings.text("Skip Forward"), selection: $forward)
                    Picker(KurtzStrings.text("Text Subtitle Size (VLC)"), selection: $subtitleConfiguration.size) {
                        Text(KurtzStrings.text("Small")).tag(13)
                        Text(KurtzStrings.text("Standard")).tag(9)
                        Text(KurtzStrings.text("Large")).tag(4)
                    }
                }
                Section(KurtzStrings.text("Playback Compatibility")) {
                    Picker(KurtzStrings.text("Preferred Player"), selection: $engine) {
                        Text(KurtzStrings.text("Automatic")).tag("automatic")
                        Text(KurtzStrings.text("Alternative — mpv")).tag("mpv")
                    }
                    Text(KurtzStrings.text("The default uses VLC. If a video fails, Try Compatible Playback offers the alternative once."))
                        .font(.footnote).foregroundStyle(.secondary)
                    Picker(KurtzStrings.text("Subtitle Text Encoding"), selection: $encoding) {
                        Text(KurtzStrings.text("Automatic")).tag("")
                        Text(verbatim: "UTF-8").tag("UTF-8")
                        Text(verbatim: "Windows-1252").tag("Windows-1252")
                        Text(verbatim: "ISO-8859-1").tag("ISO-8859-1")
                        Text(verbatim: "Shift_JIS").tag("Shift_JIS")
                    }
                    Text(KurtzStrings.text("Change only if subtitle characters look wrong. Reopen the video after changing this."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section(KurtzStrings.text("Privacy")) {
                    Text(KurtzStrings.text("Local playback needs no account. No ads, subscriptions or analytics."))
                    Button(KurtzStrings.text("Open Source Notices")) { showNotices = true }
                    Link(KurtzStrings.text("Source Code"), destination: URL(string: "https://github.com/ralleur/kurtz")!)
                    Link(KurtzStrings.text("Privacy"), destination: URL(string: "https://ralleur.github.io/kurtz/privacy.html")!)
                    Text(KurtzStrings.text("Built on Swiftfin. An independent app by Ralleur."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(KurtzStrings.text("Settings"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(KurtzStrings.text("Done")) { dismiss() }
                }
            }
            .confirmationDialog(KurtzStrings.text("Clear History"), isPresented: $confirmClear, titleVisibility: .visible) {
                Button(KurtzStrings.text("Clear History"), role: .destructive) { KurtzLocalFiles.shared.clearRecent() }
            } message: {
                Text(KurtzStrings.text("This removes saved positions and track choices. Your video files are kept."))
            }
            .sheet(isPresented: $showNotices) { KurtzNoticesView() }
            .onChange(of: history) {
                if !history {
                    KurtzLocalFiles.shared.clearRecent()
                }
            }
        }
    }
}
#endif
