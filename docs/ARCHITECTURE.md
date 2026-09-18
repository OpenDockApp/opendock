# OpenDock Architecture

OpenDock is a native macOS app (SwiftUI, macOS 26+, Liquid Glass) that replaces the
system dock with a floating glass bar made of widgets. Widgets come in two tiers,
both rendered by the same SwiftUI component set so everything shares one look.

## Repository layout

```
OpenDock/                    App target
  App/                       Entry point, app delegate, lifecycle
  Dock/                      Floating panel window, dock layout, drag/reorder
  Settings/                  Preferences window
  Marketplace/               Marketplace window (Phase 3)
  Resources/                 Assets

Packages/
  OpenDockKit/               Public SDK. DockWidget protocol, sizes, host services,
                             theme tokens, shared UI components (stat, ring, sparkline…)
  OpenDockWidgets/           First-party native widgets (clock, launcher, now playing…)
  OpenDockScripting/         JavaScriptCore runtime, host API bridge, view DSL renderer (Phase 2)
  OpenDockMarketplace/       Registry client, package installer, verification (Phase 3)

sdk/
  react/                     @opendock/react: components, hooks, reconciler (Phase 2)
  cli/                       opendock CLI: init, dev, build (Phase 2)

Registry/                    Example script widgets, manifest JSON schema

docs/                        This folder
```

## Tier 1: native widgets (Swift)

Compiled into the app from `OpenDockWidgets`. Contributors add them by pull request.
This tier is for anything that needs system access: Now Playing, CPU/memory, battery,
calendar, Wi‑Fi/Bluetooth toggles, app launcher.

```swift
public protocol DockWidget: Identifiable, Sendable {
    static var descriptor: WidgetDescriptor { get }   // id, name, icon, supported sizes
    associatedtype Body: View
    @MainActor @ViewBuilder func body(context: WidgetContext) -> Body
}
```

`WidgetContext` exposes the resolved size, theme, and host services (refresh scheduler,
storage, secrets, open URL). Widgets register with `WidgetRegistry` at launch.

## Tier 2: script widgets (JavaScript / React)

A package is a folder or zip:

```
widget/
  manifest.json   id, name, version, author, sizes, refresh, domains, settings schema
  widget.js       bundled script (plain JS or compiled React)
  icon.png
```

Scripts run in **JavaScriptCore** (ships with macOS, no dependencies), one context per
widget. Scripts have no file system, process, or DOM access. The host injects:

| API | Purpose |
|-----|---------|
| `fetch(url, { method, headers, body })` | Proxied through URLSession. Domains must be declared in the manifest. |
| `settings.get(key)` | Values the user entered in the widget settings panel. Secrets live in Keychain. |
| `storage.get / set` | Small per-widget key-value cache. |
| `render()` export | Returns a view tree (see below). |
| `onAction(name, payload)` export | Receives button presses and other events. |

### View tree protocol

The wire format between JS and Swift is a JSON tree. Swift keeps a shadow tree and
renders it with SwiftUI. Components: `hstack`, `vstack`, `zstack`, `spacer`, `text`,
`icon`, `image`, `stat`, `ring`, `gauge`, `bar`, `sparkline`, `area`, `dots`, `progress`,
`button`, `toggle`, `slider`, `list`, `canvas`. Every component inherits the dock's glass
chrome, theme, and animation. Authors cannot escape the component set; that is what
keeps the dock coherent.

### React

`@opendock/react` provides typed components and hooks plus a custom `react-reconciler`
renderer that emits create/update/remove ops into the same view tree. `useFetch` wraps
the host fetch and declares a refresh interval. The CLI bundles TSX with esbuild into
the single `widget.js` that ships. Plain JS authors can return the tree directly.

## Refresh control

The host owns scheduling. Manifest requests an interval; the host clamps it to a
minimum, batches widgets that refresh together, pauses when the dock is hidden or the
display sleeps, and applies exponential backoff on failures. Users can override the
interval per widget.

## Marketplace

Static registry, no backend for v1. `opendock-registry` on GitHub holds `index.json`
and one folder per widget. CI validates the manifest, lints the bundle, and publishes
a zip with a SHA‑256. The app fetches the index from GitHub Pages, verifies hashes on
install, shows a permission sheet listing requested domains and settings, and unpacks
into `~/Library/Application Support/OpenDock/Widgets`. Users can add third-party
registries by URL and install from a local folder for development with live reload.

## Security model

- Script widgets are sandboxed by JavaScriptCore and only reach the world through the
  host bridge.
- Network is allowlisted per manifest and shown to the user at install.
- Secrets are entered by the user, stored in Keychain, and never written to the package.
- Packages are hash-verified against the registry index.
- Native widgets are reviewed in the open-source repo before merge.

## Distribution

Direct download, notarized, App Sandbox enabled with entitlements added only where a
native widget needs them. App Store distribution is not a goal for v1.
