# Contributing to OpenDock

Thanks for helping out. This covers how to get the code running and how to send a
change. Coding conventions and pitfalls live in [AGENTS.md](AGENTS.md), and the design
is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Before you start

- **Bugs:** open an issue with your macOS version, what you expected and what happened.
- **Features:** open an issue first so we can agree on the approach. It saves you
  from building something that doesn't fit the roadmap.
- **Small fixes** (typos, obvious bugs) can go straight to a pull request.

## Fork and clone

1. Fork [OpenDockApp/opendock](https://github.com/OpenDockApp/opendock) with the
   **Fork** button on GitHub.
2. Clone your fork and add the original repo as `upstream`:

   ```sh
   git clone git@github.com:<your-username>/opendock.git
   cd opendock
   git remote add upstream git@github.com:OpenDockApp/opendock.git
   ```

3. Create a branch for your change, from an up-to-date `main`:

   ```sh
   git fetch upstream
   git switch -c fix/short-description upstream/main
   ```

To pick up new changes later, run `git fetch upstream` and rebase your branch on
`upstream/main`.

## Requirements

- macOS 26 or later
- Xcode 26 or later

## Build and run

```sh
make debug      # build and launch "OpenDock Debug"
make test       # run the OpenDockKit package tests
make kill       # quit a running OpenDock
```

Or open `OpenDock.xcodeproj` in Xcode and run the `OpenDock` scheme.

Debug builds use their own bundle identifier (`com.monawwar.OpenDock.Debug`), so their
settings, layout and permissions stay separate from a release install.

Two things to know while testing:

- OpenDock can move the **system Dock** to a side edge. Don't trigger that from a
  script or CI. Try it by hand and put your Dock back afterwards.
- The dock is a non-activating panel and never takes focus. If a change makes it steal
  focus, that's a bug.

## Where things live

| Path | What's there |
|------|--------------|
| `OpenDock/` | The app: dock window, menu bar, settings, onboarding |
| `Packages/OpenDockKit/` | The widget SDK: protocol, sizing, theme, shared components |
| `Packages/OpenDockWidgets/` | The built-in widgets |

Files added under `OpenDock/` are picked up by Xcode automatically. Don't add them to
`project.pbxproj`.

## Adding a widget

1. Add a `DockWidget` type in `Packages/OpenDockWidgets`.
2. Give it a stable ID like `dev.opendock.<name>`.
3. Register it in `OpenDockWidgets.registerAll`.

Take sizes and fonts from the theme (`theme.scaled(_:)`, `theme.contentPadding`), never
hardcoded point sizes. Keep widget state in an inner view with `@State`, and reach the
system only through `WidgetContext.services`. See the example in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and the existing widgets for patterns.

## Commits

- **One change per commit.** A feature or a fix, not a bundle.
- Start the message with a prefix: `feat:`, `fix:`, `build:`, `docs:`, `refactor:`,
  `perf:`.
- Write it as a short, plain description of what changed for the user, for example
  `fix: settings panes switch instantly without fade`. Release notes are generated
  from these messages, so they should read well on their own.

## Pull requests

1. Push your branch to your fork and open a pull request against `main`.
2. Describe what changed and why. Add a screenshot or short recording for visible changes.
3. Make sure it builds and `make test` passes.
4. If your change finishes a roadmap item, tick its box in
   [docs/ROADMAP.md](docs/ROADMAP.md).

Keep pull requests focused. Several small ones are easier to review than one large one.

## Releases

Maintainers cut a release by pushing a `v*.*.*` tag on `main`. A workflow builds, signs
and notarizes the app, then publishes a GitHub release and the update feed. Contributors
don't need to do anything here.
