# AGENTS.md — Tiffy Click Development & Release Guide

> Repository-level playbook for AI coding agents working on **Tiffy Click** (`https://github.com/pakkawatkh/Tiffy-Click`). Follow these rules and release steps consistently in every session.

---

## 1. Project Overview

- **App Name:** `Tiffy Click` (`Tiffy Click.app`)
- **Bundle Identifier:** `com.local.tiffy-click` *(never change — preserves macOS Accessibility TCC permissions and `UserDefaults`)*
- **Platform:** Native macOS 13.0+ (Apple Silicon & Intel), Swift 5.9+, SwiftUI, AppKit, CoreGraphics (`CGEventTap`), IOKit, `MultitouchSupport.framework`
- **License:** Open Source — MIT License
- **Release Portal:** `../Tiffy-App/tiffy-click/` → Live at `https://pakkawatkh.github.io/Tiffy-App/tiffy-click/`
- **Auto-Update Manifest:** `https://pakkawatkh.github.io/Tiffy-App/tiffy-click/version.json`

### Key Modules
- `Sources/TiffyClickCore/` — Pure logic (`AutoscrollMath`, `TiffyClickConfig`, `TapGestureRecognizer`, `Localization`, `MultitouchBridge`) covered by unit tests.
- `Sources/TiffyClick/` — AppKit/CGEvent runtime (`AppDelegate`, `InputController`, `AutoscrollEngine`, `AutoscrollOverlay`, `SystemServices`, `IOMultitouchMonitor`, `SettingsView`, `UpdateChecker`).
- `Sources/MultitouchSupport/` — C header declarations for Apple's `MultitouchSupport.framework`.

---

## 2. Mandatory Rules

1. **Browser-Only & Link-Safe Autoscroll:**
   - Autoscroll must activate **only** on empty webpage areas inside supported browsers (Chrome, Safari, Brave, Arc, Edge, Firefox).
   - Never intercept middle-clicks on links, buttons, browser tabs (`NSCursor.pointingHand`, `AXLink`, `AXButton`, `AXURL`), or non-browser apps (Figma, Blender, VS Code, Terminal, Finder).
2. **Main-Thread UI Safety:** Never access `NSCursor` or AppKit windows from background IOKit/Multitouch callbacks; always dispatch UI/cursor inspections onto `DispatchQueue.main`.
3. **Bilingual UI (`th` & `en`):** Every user-facing string in Menu Bar, Settings, and Update Toast must support both Thai (`th`) and English (`en`) via `L10n`.
4. **Preserve macOS Accessibility TCC Permissions:** Always sign `Tiffy Click.app` in `scripts/build_app.sh` with the persistent certificate (`MonkeyToolsDeveloper` / `MonkeyCopyDeveloper`).
5. **One-Click Auto-Updater:** Keep `UpdateChecker.versionURL` pointing to `https://pakkawatkh.github.io/Tiffy-App/tiffy-click/version.json` and preserve the floating frosted-glass toast with one-click download/unzip/replace/relaunch.

---

## 3. Standard End-to-End Release Workflow

Never stop after editing code. Complete every step below in one pass:

1. **Run all unit tests:**
   ```bash
   swift test
   ```
   All tests must pass with zero failures.
2. **Bump version** in `scripts/build_app.sh` (`CFBundleShortVersionString` and `CFBundleVersion`).
3. **Build, sign, install, and package:**
   ```bash
   ./scripts/create_dmg.sh
   ```
   This builds Release `Tiffy Click.app`, signs it, installs `/Applications/Tiffy Click.app`, creates `tiffy-click-Installer.dmg` + `tiffy-click.zip`, and syncs them to `../Tiffy-App/tiffy-click/`.
4. **Update Release Portal (`../Tiffy-App`):**
   - Update `../Tiffy-App/tiffy-click/version.json` (`latestVersion`, `releaseNotes`, `publishedAt`).
   - Update version and exact DMG/ZIP sizes in `../Tiffy-App/index.html`, `../Tiffy-App/tiffy-click/index.html`, `../Tiffy-App/README.md`, and `./README.md`.
   - Follow `../Tiffy-App/AGENTS.md` (100% English, minimal copy).
5. **Commit, push both repositories, and relaunch:**
   ```bash
   git add -A && git commit -m "chore: release vX.Y.Z - <summary>" && git push origin main
   cd ../Tiffy-App && git add -A && git commit -m "chore(release): Tiffy Click vX.Y.Z" && git push origin main
   open "/Applications/Tiffy Click.app"
   ```
