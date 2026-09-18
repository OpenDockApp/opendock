# OpenDock

An open-source, widget-based dock for macOS 26+, built with SwiftUI and Liquid Glass.

## Build

Open `OpenDock.xcodeproj` in Xcode 26 and run the `OpenDock` scheme. The app lives in
the menu bar; the dock floats at the bottom of the main screen.

```sh
xcodebuild -project OpenDock.xcodeproj -scheme OpenDock build
cd Packages/OpenDockKit && swift test
```

## Writing a native widget

Add a type to `Packages/OpenDockWidgets` and register it in `OpenDockWidgets.registerAll`.

```swift
struct HelloWidget: DockWidget {
    static let descriptor = WidgetDescriptor(
        id: "dev.example.hello", name: "Hello", summary: "Says hi.",
        symbol: "hand.wave", category: .utilities, supportedSizes: [.small]
    )
    func body(context: WidgetContext) -> some View {
        StatView(value: "Hi", caption: "from OpenDock")
    }
}
```

## Docs

- [Product](docs/PRODUCT.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)
