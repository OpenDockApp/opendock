import SwiftUI

/// Round symbol button used for transport controls and quick actions.
public struct IconButton: View {
    private let symbol: String
    private let tint: Color?
    private let size: CGFloat
    private let action: () -> Void

    public init(_ symbol: String, tint: Color? = nil, size: CGFloat = 24, action: @escaping () -> Void) {
        self.symbol = symbol
        self.tint = tint
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint ?? .primary)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(Circle().fill(.primary.opacity(0.08)))
    }
}
