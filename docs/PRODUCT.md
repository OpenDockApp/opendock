# OpenDock Product

## What it is

An open-source, widget-based dock for macOS. A single floating Liquid Glass bar that
holds live, interactive widgets: clock, weather, now playing, launchers, system stats,
timers, and anything the community builds. Native SwiftUI, macOS 26+.

## Who it is for

- Mac users who want glanceable information without opening apps or Notification Center.
- Developers who want to build a widget in an evening with React or plain JS and share it.
- Contributors who want a well-structured native codebase to add deep system widgets to.

## How we differ from closed competitors

| Them | OpenDock |
|------|----------|
| Closed, fixed widget set | Open source, two-tier widget model, community registry |
| Custom-drawn dark tiles | Real Liquid Glass, adapts to wallpaper, light and dark |
| No scripting | JavaScript / React widgets with controlled network access |
| Single vendor marketplace | Static GitHub registry anyone can fork or self-host |

## Design principles

1. **Glass is the chrome, not the content.** The bar and controls are glass; widget content sits on top and stays legible.
2. **Glanceable first.** Every widget must be readable in under a second at dock size.
3. **One component set.** Native and script widgets use the same tiles, rings, sparklines, and typography so the dock never looks patchy.
4. **Host controls the cost.** Refresh, network, and memory are governed by the app, not the widget.
5. **Safe by default.** Widgets declare what they need; users see it before install.

## Core experience

- Dock floats at the bottom (or an edge) of the screen above all windows, with auto-hide.
- Widgets snap to a size grid: small (1x1), medium (2x1), large (2x2), wide (3x1).
- Edit mode: drag to reorder, resize between supported sizes, remove, add from library.
- Per-widget settings sheet generated from the manifest schema.
- Marketplace window: browse, search, install, update, manage registries.
- Menu bar item for quick toggle, edit mode, and preferences.

## Widget sizes

| Size | Cells | Example |
|------|-------|---------|
| small | 1x1 | Clock, single stat, ring |
| medium | 2x1 | Weather + forecast, now playing |
| large | 2x2 | Calendar week, app grid |
| wide | 3x1 | Media controls, stocks list |

## Non-goals for v1

- App Store distribution.
- Windows or Linux.
- Replacing the system Dock's window management (minimize, Exposé).
