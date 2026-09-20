import SwiftUI
import OpenDockKit

struct NowPlayingWidget: DockWidget {
    static let descriptor = WidgetDescriptor(id: "dev.opendock.now-playing", name: "Now Playing",
        summary: "Whatever is playing on your Mac, from any app or browser, with playback controls.",
        symbol: "music.note", category: .media, supportedSizes: [.medium, .wide], defaultSize: .wide)
    func body(context: WidgetContext) -> some View { NowPlayingView(context: context) }
}

private struct NowPlayingView: View {
    @Environment(\.dockTheme) private var theme
    @State private var expanded = false
    let context: WidgetContext

    private var media: MediaService { context.services.media }
    private var track: MediaSnapshot? { media.nowPlaying }
    private var subtitle: String {
        if let track { return track.artist.isEmpty ? (track.appName ?? "") : track.artist }
        return media.available ? "Nothing playing" : "Unavailable on this Mac"
    }

    var body: some View {
        HStack(spacing: theme.scaled(7)) {
            Button { expanded.toggle() } label: {
                HStack(spacing: theme.scaled(7)) {
                    artwork(size: 38, corner: 8)
                    VStack(alignment: .leading, spacing: theme.scaled(2)) {
                        MarqueeText(text: track?.title ?? "Now Playing", font: theme.titleFont)
                        Text(subtitle).font(theme.captionFont).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            if let track, context.size == .wide {
                HStack(spacing: theme.scaled(2)) {
                    IconButton("backward.fill", size: theme.scaled(22)) { media.send(.previous) }.accessibilityLabel("Previous track")
                    IconButton(track.playing ? "pause.fill" : "play.fill", size: theme.scaled(26)) { media.send(.toggle) }
                        .accessibilityLabel(track.playing ? "Pause" : "Play")
                    IconButton("forward.fill", size: theme.scaled(22)) { media.send(.next) }.accessibilityLabel("Next track")
                }
            }
        }.padding(theme.contentPadding)
        .widgetPopover(isPresented: $expanded) {
            WidgetDetails(title: "Now Playing", symbol: "music.note") {
                if let track {
                    HStack(spacing: theme.scaled(10)) {
                        artwork(size: 64, corner: 10)
                        VStack(alignment: .leading, spacing: theme.scaled(4)) {
                            Text(track.title).font(theme.titleFont)
                            if !track.artist.isEmpty { Text(track.artist).foregroundStyle(.secondary) }
                            if let app = track.appName { Text(app).font(theme.captionFont).foregroundStyle(.tertiary) }
                        }
                    }
                    HStack {
                        Spacer()
                        IconButton("backward.fill", size: theme.scaled(32)) { media.send(.previous) }.accessibilityLabel("Previous track")
                        IconButton(track.playing ? "pause.fill" : "play.fill", tint: theme.accent, size: theme.scaled(38)) { media.send(.toggle) }
                            .accessibilityLabel(track.playing ? "Pause" : "Play")
                        IconButton("forward.fill", size: theme.scaled(32)) { media.send(.next) }.accessibilityLabel("Next track")
                        Spacer()
                    }
                    if let app = track.appName, track.bundleID != nil {
                        Button("Open \(app)") { media.openPlayer() }.buttonStyle(.glass)
                    }
                } else {
                    Text(subtitle).foregroundStyle(.secondary)
                }
                Text("Works with any app that shows up in Control Center's Now Playing.")
                    .font(theme.captionFont).foregroundStyle(.secondary)
            }.environment(\.dockTheme, theme)
        }
        .onAppear { media.start() }
    }

    private func artwork(size: CGFloat, corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: theme.scaled(corner)).fill(theme.accent.opacity(0.12))
            .overlay { Image(systemName: "music.note").font(theme.statFont).foregroundStyle(theme.accent) }
            .frame(width: theme.scaled(size), height: theme.scaled(size))
    }
}

/// One line of text that scrolls back and forth when it does not fit, like Control Center.
private struct MarqueeText: View {
    @Environment(\.dockTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var boxWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    let text: String
    let font: Font

    var body: some View {
        if reduceMotion {
            Text(text).font(font).lineLimit(1)
        } else {
            // The hidden copy sets the height and lets the box shrink; the overlay scrolls.
            Text(text).font(font).lineLimit(1).hidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    Text(text).font(font).lineLimit(1).fixedSize()
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
                        .offset(x: offset)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { boxWidth = $0 }
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(text)
                .task(id: "\(text)|\(textWidth)|\(boxWidth)") { await scroll() }
        }
    }

    private func scroll() async {
        offset = 0
        let overflow = textWidth - boxWidth
        guard overflow > 1 else { return }
        let duration = Double(overflow / theme.scaled(30))
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(2))
                withAnimation(.linear(duration: duration)) { offset = -overflow }
                try await Task.sleep(for: .seconds(duration + 1.5))
                withAnimation(.easeInOut(duration: 0.4)) { offset = 0 }
                try await Task.sleep(for: .seconds(0.4))
            } catch { return }
        }
    }
}
