//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// Vela Mac menu bar integration. Licensed under MPL-2.0.
#if targetEnvironment(macCatalyst)
import UIKit

final class VelaFileMenuDelegate: UIResponder, UIApplicationDelegate {
    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else { return }
        let open = UIKeyCommand(
            title: VelaStrings.text("Open Video…"),
            action: #selector(UIResponder.velaOpenFile(_:)),
            input: "o",
            modifierFlags: .command
        )
        let subtitle = UIKeyCommand(
            title: VelaStrings.text("Add Subtitle File…"),
            action: #selector(UIResponder.velaOpenSubtitle(_:)),
            input: "o",
            modifierFlags: [.command, .shift]
        )
        let recent = UIMenu(
            title: VelaStrings.text("Open Recent"),
            identifier: .init("vela.recents"),
            children: VelaLocalFiles.shared.recent.map { entry in
                UIAction(title: entry.url.lastPathComponent) { _ in VelaLocalFiles.shared.reopen(entry) }
            } + [UIAction(title: VelaStrings.text("Clear History")) { _ in VelaLocalFiles.shared.clearRecent() }]
        )
        let fallback = UIKeyCommand(
            title: VelaStrings.text("Try Compatible Playback"),
            action: #selector(UIResponder.velaSwitchEngine(_:)),
            input: "p",
            modifierFlags: [.command, .alternate]
        )
        if VelaLocalFiles.shared.activeManager?.playbackItem?.discoversTracks != true {
            subtitle.attributes = .disabled
        }
        if VelaLocalFiles.shared.activeManager?.retryPlayback == nil {
            fallback.attributes = .disabled
        }
        var children: [UIMenuElement] = [open, recent, subtitle, fallback]
        #if DEBUG
        children.append(UIKeyCommand(
            title: "Run Replacement Checks",
            action: #selector(UIResponder.velaRunReplacementChecks(_:)),
            input: "r",
            modifierFlags: [.command, .alternate, .control]
        ))
        children.append(UIKeyCommand(
            title: "Run Local Playback Checks",
            action: #selector(UIResponder.velaRunPlaybackChecks(_:)),
            input: "t",
            modifierFlags: [.command, .alternate, .control]
        ))
        #endif
        builder.remove(menu: .open)
        builder.remove(menu: .openRecent)
        builder.replaceChildren(ofMenu: .file) { existing in
            [UIMenu(title: "", identifier: .init("vela.fileActions"), options: .displayInline, children: children)] + existing
        }
    }
}

extension UIResponder {
    #if DEBUG
    @objc
    func velaRunReplacementChecks(_ sender: Any?) {
        Task { await VelaLocalPlaybackChecks.runReplacementChecks() }
    }

    @objc
    func velaRunPlaybackChecks(_ sender: Any?) {
        Task { await VelaLocalPlaybackChecks.run() }
    }
    #endif
    @objc
    func velaOpenFile(_ sender: Any?) {
        VelaLocalFiles.shared.showPicker(subtitle: false)
    }

    @objc
    func velaSwitchEngine(_ sender: Any?) {
        VelaLocalFiles.shared.switchEngine()
    }

    @objc
    func velaOpenSubtitle(_ sender: Any?) {
        VelaLocalFiles.shared.showPicker(subtitle: true)
    }
}
#endif
