# AGENTS.md

Guide for coding agents working on OpenDock. Read `docs/PRODUCT.md`,
`docs/ARCHITECTURE.md` and `docs/ROADMAP.md` for the why; this file covers the how.

## What this is

A native macOS 26+ widget dock. SwiftUI with Liquid Glass inside AppKit-managed
windows, a menu bar agent app (`LSUIElement`), sandboxed, distributed outside the App Store. Only macOS; do not add
iOS or cross-platform code.

## Layout

```
OpenDock/                 App target (file-system synchronized group)
  App/                    OpenDockMain (@main, AppKit lifecycle), AppDelegate,
                          StatusMenuController (NSStatusItem + NSMenu)
  Dock/                   DockPanel (NSPanel), DockPanelController (frame, auto-hide),
                          DockView (glass bar + tiles), DockLayoutStore (persisted layout)
  Onboarding/             First-run window and steps
  Services/               PermissionCenter, LaunchAtLogin, SystemDockManager
  Settings/               SettingsWindowController (toolbar-style NSTabViewController)
                          + SwiftUI panes in SettingsPanes.swift
  Resources/              Assets
Packages/
  OpenDockKit/            Public widget SDK: DockWidget, WidgetDescriptor, WidgetSize,
                          WidgetContext, WidgetRegistry, DockTheme, HostServices, components
  OpenDockWidgets/        First-party native widgets, registered in OpenDockWidgets.registerAll
Helpers/MediaRemoteBridge/     ObjC dylib for Now Playing, built by the "Build Media Bridge"
                               script phase into Contents/Frameworks (kept out of OpenDock/)
Config/OpenDock.entitlements   Extra entitlements merged with build-setting entitlements
docs/                     Product, architecture, roadmap
```

Planned but not created yet: `Packages/OpenDockScripting`, `Packages/OpenDockMarketplace`,
`sdk/react`, `sdk/cli`, `Registry/`. Follow `docs/ARCHITECTURE.md` when adding them.

## Build and test

```sh
xcodebuild -project OpenDock.xcodeproj -scheme OpenDock -configuration Debug build
cd Packages/OpenDockKit && swift test
```

No xcodegen or tuist. Use a scratch `-derivedDataPath` when building from a shell.

- Files added under `OpenDock/` are picked up automatically (synchronized group). Do
  not add them to `project.pbxproj`.
- A new local Swift package needs manual `project.pbxproj` entries: an
  `XCLocalSwiftPackageReference`, an `XCSwiftPackageProductDependency`, a
  `PBXBuildFile` in the Frameworks phase, and `packageProductDependencies` on the
  target. Run `plutil -lint` on the project file after editing.
- Packages use `swift-tools-version: 6.2`, `platforms: [.macOS("26.0")]` and
  `.defaultIsolation(MainActor.self)`. The app target also defaults to MainActor.

## Conventions

- **Sizing comes from the theme.** Never hardcode point sizes in widgets or
  components. Use `theme.scaled(_:)`, `theme.contentPadding` and the theme fonts
  (`heroFont`, `statFont`, `titleFont`, `captionFont`). Everything derives from
  `DockTheme.cellSize` (64 pt reference).
- **Glass is chrome only.** The bar uses `.glassEffect`. Tiles are a subtle filled
  surface (`WidgetTile`) so glass never samples glass. Group adjacent glass elements
  in a `GlassEffectContainer`. Use `.buttonStyle(.glass)` / `.glassProminent`.
- **New native widget:** add a `DockWidget` type in `Packages/OpenDockWidgets`, give it
  a stable reverse-DNS `id` (`dev.opendock.<name>`), register it in `registerAll`.
  Keep widget state in an inner view with `@State`; the widget struct is recreated
  freely. Reach the system only through `WidgetContext.services`.
- **Widget popovers use `widgetPopover(isPresented:)`**, not `.popover`. It tells the
  dock right away, so the dock does not auto-hide before SwiftUI shows the popover
  (which lags, e.g. when opened from a context menu).
- **Persistence:** app settings go in `UserDefaults` with namespaced keys
  (`dock.autoHide`, `dock.bottomGap`, `systemDock.snapshot`, `onboarding.completed`).
  The layout is JSON in Application Support under a folder named by bundle ID.
- **Edit mode is a draft.** `DockLayoutStore.beginEditing` snapshots the layout;
  mutations are not written to disk until `commitEditing` (OK). `cancelEditing`
  restores the snapshot. Drags use `DockDragPayload` strings: `newWidget` from the
  tray, `placedItem` for tiles already in the dock.
- **New permission:** add a case to `PermissionCenter.Kind`, the matching
  `INFOPLIST_KEY_*UsageDescription` and `ENABLE_RESOURCE_ACCESS_*` build settings in
  both Debug and Release, and it appears in onboarding automatically.

## Pitfalls already hit

- The app uses the AppKit lifecycle on purpose. SwiftUI `MenuBarExtra` menus lagged
  on hover, so the status menu is a plain `NSMenu` rebuilt in `menuNeedsUpdate`. Do not
  move back to a SwiftUI `App`/`MenuBarExtra`. Windows (settings, onboarding) are
  `NSWindow`s hosting SwiftUI; there is no SwiftUI `Settings` scene.
- The dock panel must stay a non-activating borderless `NSPanel` so it never steals
  focus. Hover uses an `NSTrackingArea` with `.activeAlways`; reveal uses the same
  on `EdgeTrigger`, a 2 pt strip at the bottom edge shown while the dock is hidden.
- Never add a global `.mouseMoved` event monitor. It routes every pointer move on the
  system through the app and makes all of its menus lag on hover, with an idle main
  thread, so profiling does not show it.
- The panel is offset down by `DockView.shadowMargin` so the shadow padding does not
  add to the visible bottom gap. Keep those two in sync.
- The sandbox cannot disable the system Dock. `SystemDockManager` moves it to a side
  edge and auto-hides it via System Events. Do not run it during testing without the
  user's say-so, since it changes their real Dock.
- MediaRemote only answers Apple-signed processes (macOS 15.4+), so a normal binary gets
  nil now-playing info. `MediaService` loads `libMediaRemoteBridge.dylib` into
  `/usr/bin/perl`, which is entitled, and reads JSON lines from it. This works inside the
  sandbox. Perl calls `OpenDockMediaBridgeRun` as an XSUB after loading; never run the
  bridge from a load constructor, since dyld's loader lock makes MediaRemote stop replying. The bridge does not return artwork yet: the info dictionary has the artwork
  metadata but no bytes.
- Debug builds are `com.monawwar.OpenDock.Debug` with display name "OpenDock Debug".
  Their window owner name and sandbox container differ from release.
- Screen capture is usually unavailable from an agent shell. To check the dock is on
  screen, list windows with `CGWindowListCopyWindowInfo` and match owner names that
  start with "OpenDock". Launch with `open <App>.app` so the app outlives the shell.

## Git

- One commit per feature or fix. Do not bundle unrelated changes into one commit.
- Conventional prefixes: `feat:`, `fix:`, `build:`, `docs:`, `refactor:`.
- Update the checkboxes in `docs/ROADMAP.md` when a roadmap item lands.
