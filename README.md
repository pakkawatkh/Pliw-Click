# 🖱️ tiffy-click

**Universal Middle-Click, Middle-Drag & Windows-Style Autoscroll for macOS**

`tiffy-click` brings true Windows-style middle-click scrolling (Hold Scroll & Toggle Autoscroll) and 3-finger Trackpad / Magic Mouse middle-click + middle-drag to every app on macOS 13.0+.

## ✨ Features

- **Windows-Style Universal Autoscroll (Hold Scroll & Toggle):**
  - **Smart Mode (Default):** Middle-click on empty page areas to lock 4-way Autoscroll (with a floating 4-direction HUD indicator), or hold & move to scroll and stop on release. Middle-clicking on links (`AXLink`) or browser tabs (`AXTab`) still opens/closes tabs normally!
  - **Hold & Drag Mode:** Hold middle button / 3-finger click and move to scroll; quick click behaves as standard middle click.
  - **Works System-Wide:** Chrome, Safari, Arc, Brave, Edge, VS Code, PDF viewers, and more — for both **Physical Mouse** and **Trackpad**.
- **Full Middle-Drag Support:** Properly translates 3-finger drag into `.otherMouseDragged` (`.center`) for panning/orbiting in Figma, Blender, and CAD apps.
- **Multitouch Trackpad & Magic Mouse:** Configurable 2–5 fingers, Tap-to-Click, adjustable tap speed/distance, and built-in **Palm Rejection** edge filtering.
- **Per-App Rules & Settings UI:** Native SwiftUI Settings window, one-click ignore for focused app (or disable Autoscroll only while keeping Middle-Drag), Launch at Login, and In-App Update Checker.
- **System Resilience:** Automatically recovers listeners after Sleep/Wake, Fast User Switching, Display reconfiguration, and Magic Mouse/Trackpad hot-plugging.

## 🛠️ Build & Test

```bash
swift test
./scripts/build_app.sh
./scripts/create_dmg.sh
```

## 📜 License & Credits

Licensed under **GPL-3.0**. Inspired by [artginzburg/MiddleClick](https://github.com/artginzburg/MiddleClick).
