import SwiftUI

/// Circular progress ring with a label in the middle.
public struct RingView: View {
    private let progress: Double
    private let label: String
    private let symbol: String?
    private let tint: Color
    private let lineWidth: CGFloat

    public init(progress: Double, label: String, symbol: String? = nil, tint: Color = .accentColor, lineWidth: CGFloat = 7) {
        self.progress = min(max(progress, 0), 1)
        self.label = label
        self.symbol = symbol
        self.tint = tint
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            VStack(spacing: 0) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(label)
                    .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .padding(16)
    }
}
