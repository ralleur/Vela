//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// kurtz Mac menu bar integration. Licensed under MPL-2.0.
#if targetEnvironment(macCatalyst)
import UIKit

final class KurtzFileMenuDelegate: UIResponder, UIApplicationDelegate {
    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else { return }
        let open = UIKeyCommand(
            title: KurtzStrings.text("Open Video…"),
            action: #selector(UIResponder.kurtzOpenFile(_:)),
            input: "o",
            modifierFlags: .command
        )
        let subtitle = UIKeyCommand(
            title: KurtzStrings.text("Add Subtitle File…"),
            action: #selector(UIResponder.kurtzOpenSubtitle(_:)),
            input: "o",
            modifierFlags: [.command, .shift]
        )
        let recent = UIMenu(
            title: KurtzStrings.text("Open Recent"),
            identifier: .init("kurtz.recents"),
            children: KurtzLocalFiles.shared.recent.map { entry in
                UIAction(title: entry.url.lastPathComponent) { _ in KurtzLocalFiles.shared.reopen(entry) }
            } + [UIAction(title: KurtzStrings.text("Clear History")) { _ in KurtzLocalFiles.shared.clearRecent() }]
        )
        let fallback = UIKeyCommand(
            title: KurtzStrings.text("Try Compatible Playback"),
            action: #selector(UIResponder.kurtzSwitchEngine(_:)),
            input: "p",
            modifierFlags: [.command, .alternate]
        )
        if KurtzLocalFiles.shared.activeManager?.playbackItem?.discoversTracks != true {
            subtitle.attributes = .disabled
        }
        if KurtzLocalFiles.shared.activeManager?.retryPlayback == nil {
            fallback.attributes = .disabled
        }
        var children: [UIMenuElement] = [open, recent, subtitle, fallback]
        #if DEBUG
        children.append(UIKeyCommand(
            title: "Run Replacement Checks",
            action: #selector(UIResponder.kurtzRunReplacementChecks(_:)),
            input: "r",
            modifierFlags: [.command, .alternate, .control]
        ))
        children.append(UIKeyCommand(
            title: "Run Local Playback Checks",
            action: #selector(UIResponder.kurtzRunPlaybackChecks(_:)),
            input: "t",
            modifierFlags: [.command, .alternate, .control]
        ))
        #endif
        builder.remove(menu: .open)
        builder.remove(menu: .openRecent)
        builder.replaceChildren(ofMenu: .file) { existing in
            [UIMenu(title: "", identifier: .init("kurtz.fileActions"), options: .displayInline, children: children)] + existing
        }
    }
}

extension UIResponder {
    #if DEBUG
    @objc
    func kurtzRunReplacementChecks(_ sender: Any?) {
        Task { await KurtzLocalPlaybackChecks.runReplacementChecks() }
    }

    @objc
    func kurtzRunPlaybackChecks(_ sender: Any?) {
        Task { await KurtzLocalPlaybackChecks.run() }
    }
    #endif
    @objc
    func kurtzOpenFile(_ sender: Any?) {
        KurtzLocalFiles.shared.showPicker(subtitle: false)
    }

    @objc
    func kurtzSwitchEngine(_ sender: Any?) {
        KurtzLocalFiles.shared.switchEngine()
    }

    @objc
    func kurtzOpenSubtitle(_ sender: Any?) {
        KurtzLocalFiles.shared.showPicker(subtitle: true)
    }
}
#endif
