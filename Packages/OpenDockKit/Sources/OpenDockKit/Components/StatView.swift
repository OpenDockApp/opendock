import SwiftUI

/// Big number with a caption. The workhorse of small widgets.
public struct StatView: View {
    @Environment(\.dockTheme) private var theme

    private let value: String
    private let caption: String?
    private let symbol: String?
    private let tint: Color?

    public init(value: String, caption: String? = nil, symbol: String? = nil, tint: Color? = nil) {
        self.value = value
        self.caption = caption
        self.symbol = symbol
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: theme.scaled(10), weight: .semibold))
                    .foregroundStyle(tint ?? .secondary)
            }
            Text(value)
                .font(theme.statFont)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let caption {
                Text(caption)
                    .font(theme.captionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(theme.contentPadding)
    }
}
