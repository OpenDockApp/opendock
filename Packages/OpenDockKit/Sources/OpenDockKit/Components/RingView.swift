import SwiftUI

/// Circular progress ring with a label in the middle.
public struct RingView: View {
    @Environment(\.dockTheme) private var theme
    private let progress: Double
    private let label: String
    private let symbol: String?
    private let tint: Color
    private let lineWidth: CGFloat

    public init(progress: Double, label: String, symbol: String? = nil, tint: Color = .accentColor, lineWidth: CGFloat = 4) {
        self.progress = min(max(progress, 0), 1)
        self.label = label
        self.symbol = symbol
        self.tint = tint
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: theme.scaled(lineWidth))
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: theme.scaled(lineWidth), lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            VStack(spacing: 0) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: theme.scaled(7), weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(label)
                    .font(.system(size: theme.scaled(14), weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .padding(theme.scaled(7))
    }
}
