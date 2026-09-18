import SwiftUI

/// Smooth line chart with a soft fill underneath. Values are normalized automatically.
public struct SparklineView: View {
    private let values: [Double]
    private let tint: Color
    private let lineWidth: CGFloat

    public init(values: [Double], tint: Color = .accentColor, lineWidth: CGFloat = 1.5) {
        self.values = values
        self.tint = tint
        self.lineWidth = lineWidth
    }

    public var body: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)
            if points.count > 1 {
                ZStack {
                    fillPath(points, height: geo.size.height)
                        .fill(LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                    linePath(points)
                        .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, let min = values.min(), let max = values.max() else { return [] }
        let range = max - min == 0 ? 1 : max - min
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) * stepX, y: size.height - CGFloat((v - min) / range) * size.height)
        }
    }

    private func linePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.move(to: points[0])
        for i in 1..<points.count {
            let prev = points[i - 1], cur = points[i]
            let mid = CGPoint(x: (prev.x + cur.x) / 2, y: (prev.y + cur.y) / 2)
            path.addQuadCurve(to: mid, control: prev)
            path.addQuadCurve(to: cur, control: cur)
        }
        return path
    }

    private func fillPath(_ points: [CGPoint], height: CGFloat) -> Path {
        var path = linePath(points)
        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: height))
        path.addLine(to: CGPoint(x: points[0].x, y: height))
        path.closeSubpath()
        return path
    }
}
