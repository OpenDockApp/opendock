# OpenDock Roadmap

## Phase 1: Base (done)

Goal: a floating glass dock with native widgets and a clean SDK, built and committed.

- [x] Strip template code, set up folder structure and local Swift packages
- [x] `OpenDockKit`: `DockWidget` protocol, `WidgetDescriptor`, `WidgetSize`, `WidgetContext`, `WidgetRegistry`, theme tokens
- [x] Shared UI components: tile container, stat, ring, sparkline, icon button
- [x] Floating `NSPanel` at screen bottom, non-activating, all spaces, Liquid Glass background
- [x] Dock layout engine with size grid and `GlassEffectContainer`
- [x] Menu bar item with show/hide, edit mode, quit
- [x] First-party widgets: Clock, Date, App Launcher, CPU ring
- [x] Persist layout to disk
- [x] Edit mode: reorder and remove

## Phase 2: Scripting and React (next)

Goal: third parties can build widgets without Xcode.

- [ ] `OpenDockScripting`: JavaScriptCore runtime, one context per widget
- [ ] Host bridge: `fetch` with domain allowlist, `settings`, `storage`, actions
- [ ] View tree protocol and SwiftUI renderer for the full component set
- [ ] Refresh scheduler with clamping, batching, pause, and backoff
- [ ] Manifest schema and validator
- [ ] Load widgets from `~/Library/Application Support/OpenDock/Widgets`
- [ ] `@opendock/react`: components, hooks, reconciler
- [ ] `opendock` CLI: `init`, `dev` with live reload, `build`
- [ ] Example widgets in `Registry/`: GitHub stars, weather, crypto price
- [ ] Settings sheet generated from manifest schema, secrets in Keychain

## Phase 3: Marketplace

Goal: discover, install, and update community widgets from inside the app.

- [ ] `opendock-registry` repo with `index.json`, CI validation, zip + SHA-256 publishing
- [ ] `OpenDockMarketplace`: registry client, installer, hash verification, updates
- [ ] Marketplace window: browse, search, categories, screenshots, install
- [ ] Permission sheet on install listing domains and settings
- [ ] Third-party registries by URL
- [ ] Update check on launch

## Phase 4: More native widgets and polish

- [x] Now Playing with Music/Spotify artwork and transport controls
- [x] Next Meeting with calendar access, countdown, and conference links
- [x] Weather with saved city, current conditions, highs/lows, and unit selection (Open-Meteo)
- [ ] Reminders, Mail unread
- [x] Battery with charge, power source, and time estimates
- [ ] Memory, network throughput, disk
- [ ] Wi‑Fi, Bluetooth, Do Not Disturb toggles
- [x] Focus timer with persistent sessions, pause/resume, and breaks
- [ ] Stopwatch
- [ ] Multiple docks and edge placement
- [ ] Keyboard shortcuts, accessibility pass, reduced transparency support
- [ ] Notarized release pipeline and Sparkle updates

## Later ideas

- Canvas component for custom drawing in script widgets
- Web view escape hatch for widgets that need HTML
- Optional registry API for ratings and featured lists
- iCloud sync of dock layout
