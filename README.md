# 🖱️ Pliw Click

**Middle-Click, Middle-Drag & macOS Liquid Glass Browser Autoscroll**

[![Version](https://img.shields.io/badge/Release-v1.3.0-06b6d4?style=for-the-badge)](https://pakkawatkh.github.io/Pliw-App/pliw-click/)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-lightgrey?style=for-the-badge&logo=apple)](https://github.com/pakkawatkh/Pliw-Click)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

`Pliw Click` brings Windows-style smooth **Browser Autoscroll** (with a compact `28pt` Apple Liquid Glass 360° orb) plus 2–10 finger Trackpad / Magic Mouse **Middle-Click, Tap & Middle-Drag** to macOS 13.0+.

- 🌐 **Live Website & Interactive Preview:** https://pakkawatkh.github.io/Pliw-App/pliw-click/
- 📥 **Direct Download (DMG · 2.1 MB):** https://pakkawatkh.github.io/Pliw-App/pliw-click/pliw-click-Installer.dmg
- 🗜️ **ZIP Archive (1.7 MB):** https://pakkawatkh.github.io/Pliw-App/pliw-click/pliw-click.zip

---

## ✨ Features & Usage Examples

- **🫧 Apple Liquid Glass 360° Browser Autoscroll:**
  - Middle-click (physical mouse or multi-finger Trackpad) on **empty webpage areas** in Chrome, Safari, Brave, Arc, Edge, or Firefox to activate the compact `28pt` frosted-glass orb.
  - A slender rim-hugging chevron orbits **360°** toward your cursor as you scroll, and disappears cleanly when idle.
- **🎯 Smart Link, Tab & Non-Browser Protection:**
  - Automatically detects pointing-hand cursors (`NSCursor.pointingHand`), links (`AXLink`), buttons (`AXButton`), and browser tabs — middle-clicking a link still opens a new tab, and middle-clicking a tab still closes it.
  - Outside web browsers (VS Code, Figma, Blender, Terminal, Finder), middle-click & middle-drag work 100% natively.
- **🖐️ 2–10 Finger Trackpad Click, Tap & Full Middle-Drag:**
  - Configurable 2–10 fingers right from the Menu Bar, optional `N+` fingers, Tap-to-Click, edge **Palm Rejection**, and proper `.otherMouseDragged` support.
- **🇹🇭 / 🇺🇸 Minimal macOS UI & Floating Update Toast:**
  - Bilingual English (`en`) & Thai (`th`) interface, native SwiftUI Settings, Launch at Login, and an auto-fading frosted-glass update toast with one-click in-app updates.

---

## 🚀 Installation Guide

1. Download **`pliw-click-Installer.dmg`** from the link above and double-click to open it.
2. Drag **`Pliw Click.app`** into the **Applications** folder.
3. **First-Time Launch (macOS Gatekeeper):**
   - Open **System Settings → Privacy & Security → Open Anyway**, **or**
   - Run in Terminal:
     ```bash
     xattr -cr "/Applications/Pliw Click.app"
     ```
4. **Accessibility Permission:**
   - Enable **Pliw Click** in **System Settings → Privacy & Security → Accessibility**.

---

## 🛠️ Build & Test from Source

```bash
swift test
./scripts/build_app.sh
./scripts/create_dmg.sh
```

## 📄 License

Open Source — Licensed under the **[MIT License](LICENSE)**. Copyright © 2026 Pakkawat.k.
