import SwiftUI
import OpenDockKit

struct NowPlayingWidget: DockWidget {
    static let descriptor = WidgetDescriptor(id: "dev.opendock.now-playing", name: "Now Playing",
        summary: "Music and Spotify artwork, track details, and playback controls.",
        symbol: "music.note", category: .media, supportedSizes: [.medium, .wide], defaultSize: .wide)
    func body(context: WidgetContext) -> some View { NowPlayingView(context: context) }
}

private struct NowPlayingView: View {
    @Environment(\.dockTheme) private var theme
    @State private var expanded = false
    @State private var source: MediaSource = .music
    @State private var snapshot: MediaSnapshot?
    @State private var busy = false
    @State private var message: String?
    @State private var restored = false
    let context: WidgetContext

    private var hasTrack: Bool { snapshot?.state == .track }
    private var subtitle: String {
        switch snapshot?.state {
        case .closed: "Open \(source.name)"
        case .needsPermission: "Connect \(source.name)"
        case .denied: "Allow Automation"
        case .idle: "Play something in \(source.name)"
        case .track: snapshot?.artist ?? ""
        case .unavailable: "Player unavailable"
        case nil: "Checking \(source.name)…"
        }
    }

    var body: some View {
        HStack(spacing: theme.scaled(7)) {
            Button { expanded.toggle() } label: {
                HStack(spacing: theme.scaled(7)) {
                    artwork.frame(width: theme.scaled(38), height: theme.scaled(38))
                        .clipShape(RoundedRectangle(cornerRadius: theme.scaled(8)))
                    VStack(alignment: .leading, spacing: theme.scaled(2)) {
                        Text(hasTrack ? snapshot!.title : "Now Playing").font(theme.titleFont).lineLimit(1)
                        Text(subtitle).font(theme.captionFont).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            if hasTrack && context.size == .wide {
                IconButton(snapshot?.playing == true ? "pause.fill" : "play.fill", size: theme.scaled(26)) { send(.toggle) }
                    .disabled(busy).accessibilityLabel(snapshot?.playing == true ? "Pause" : "Play")
            }
        }.padding(theme.contentPadding)
        .popover(isPresented: $expanded) {
            WidgetDetails(title: "Now Playing", symbol: "music.note") {
                Picker("Player", selection: $source) {
                    ForEach(MediaSource.allCases, id: \.self) { Text($0.name).tag($0) }
                }.pickerStyle(.segmented)
                if hasTrack {
                    HStack(spacing: theme.scaled(10)) {
                        artwork.frame(width: theme.scaled(64), height: theme.scaled(64))
                            .clipShape(RoundedRectangle(cornerRadius: theme.scaled(10)))
                        VStack(alignment: .leading, spacing: theme.scaled(4)) {
                            Text(snapshot!.title).font(theme.titleFont)
                            Text(snapshot!.artist).foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Spacer()
                        IconButton("backward.fill", size: theme.scaled(32)) { send(.previous) }.accessibilityLabel("Previous track")
                        IconButton(snapshot?.playing == true ? "pause.fill" : "play.fill", tint: theme.accent, size: theme.scaled(38)) { send(.toggle) }
                            .accessibilityLabel(snapshot?.playing == true ? "Pause" : "Play")
                        IconButton("forward.fill", size: theme.scaled(32)) { send(.next) }.accessibilityLabel("Next track")
                        Spacer()
                    }.disabled(busy)
                } else {
                    Text(subtitle).foregroundStyle(.secondary)
                    if snapshot?.state == .needsPermission || snapshot?.state == .denied {
                        Button(snapshot?.state == .denied ? "Open Automation Privacy" : "Connect \(source.name)") {
                            if snapshot?.state == .denied {
                                context.services.openURL(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
                            } else {
                                busy = true
                                let requestedSource = source
                                Task {
                                    let result = await context.services.media.snapshot(for: requestedSource, requestPermission: true)
                                    if source == requestedSource { snapshot = result }
                                    busy = false
                                }
                            }
                        }.buttonStyle(.glassProminent).disabled(busy)
                    }
                }
                if let message { Text(message).foregroundStyle(.secondary) }
                Button("Open \(source.name)") {
                    message = context.services.media.open(source) ? nil : "\(source.name) is not installed on this Mac."
                }.buttonStyle(.glass)
                Text("Works with the Music and Spotify desktop apps.").font(theme.captionFont).foregroundStyle(.secondary)
            }.environment(\.dockTheme, theme)
        }
        .onAppear {
            guard !restored else { return }
            source = context.services.storage.get("media.source", instance: context.instanceID, as: MediaSource.self) ?? .music
            restored = true
        }
        .onChange(of: source) { _, value in
            snapshot = nil; message = nil
            context.services.storage.set(value, for: "media.source", instance: context.instanceID)
        }
        .task(id: source) {
            let requestedSource = source
            while !Task.isCancelled {
                if !busy {
                    let result = await context.services.media.snapshot(for: requestedSource)
                    guard !Task.isCancelled, source == requestedSource else { return }
                    snapshot = result
                }
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
        }
    }
    @ViewBuilder private var artwork: some View {
        if let data = snapshot?.artwork, let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: theme.scaled(8)).fill(theme.accent.opacity(0.12))
                .overlay { Image(systemName: "music.note").font(theme.statFont).foregroundStyle(theme.accent) }
        }
    }
    private func send(_ command: MediaService.Command) {
        guard !busy else { return }
        busy = true
        let requestedSource = source
        Task {
            let success = await context.services.media.command(command, source: requestedSource)
            let result = await context.services.media.snapshot(for: requestedSource)
            if source == requestedSource {
                snapshot = result
                message = success ? nil : "Playback command failed. Try again."
            }
            busy = false
        }
    }
}
