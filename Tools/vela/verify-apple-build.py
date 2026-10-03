#!/usr/bin/env python3
"""Inspect an iOS/tvOS app bundle. Does not establish signing or Store eligibility."""
import argparse
import plistlib
from pathlib import Path


def verify(app: Path, platform: str) -> None:
    with (app / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    assert info["CFBundleIdentifier"] == "com.ralleur.vela", "Unexpected app identity"
    assert info["CFBundleDisplayName"] == "Vela", "Unexpected display name"
    assert info["CFBundleShortVersionString"].startswith("0.9."), "Expected a Vela beta"
    assert int(info["CFBundleVersion"]) > 0, "Missing build number"
    assert (app / info["CFBundleExecutable"]).is_file(), "Missing executable"
    assert (app / "Assets.car").is_file(), "Missing compiled assets"
    assert (app / "VelaThirdPartyNotices.txt").is_file(), "Missing offline notices"
    assert info["MinimumOSVersion"] == ("18.6" if platform == "ios" else "26.1"), "Recheck documented OS minimum"
    assert set(info["UIDeviceFamily"]) == ({1, 2} if platform == "ios" else {3}), "Unexpected device family"
    schemes = {s for entry in info.get("CFBundleURLTypes", []) for s in entry.get("CFBundleURLSchemes", [])}
    assert schemes == {"vela"}, "App must register its own URL scheme"
    with (app / "PrivacyInfo.xcprivacy").open("rb") as stream:
        privacy = plistlib.load(stream)
    assert privacy["NSPrivacyTracking"] is False, "Unexpected tracking declaration"
    assert any(entry["NSPrivacyAccessedAPIType"] == "NSPrivacyAccessedAPICategoryUserDefaults"
               and "CA92.1" in entry["NSPrivacyAccessedAPITypeReasons"]
               for entry in privacy["NSPrivacyAccessedAPITypes"]), "Missing defaults reason"
    if platform == "ios":
        for key in ("CFBundleIcons", "CFBundleIcons~ipad"):
            assert not info.get(key, {}).get("CFBundleAlternateIcons"), "Unexpected upstream alternate app icons"
        assert info.get("LSSupportsOpeningDocumentsInPlace") is True
        assert info.get("CFBundleDocumentTypes"), "Missing video document registration"
        assert not info.get("UIRequiresFullScreen", False), "iPad should support resizable presentation"
    print(f"PASS {platform}: Vela {info['CFBundleShortVersionString']} ({info['CFBundleVersion']}); "
          "identity, device families, resources, privacy declaration and document configuration.")
    print("Device playback, signing, dependency privacy and Store licensing remain separate checks.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=["ios", "tvos"])
    parser.add_argument("app", type=Path)
    args = parser.parse_args()
    verify(args.app, args.platform)
