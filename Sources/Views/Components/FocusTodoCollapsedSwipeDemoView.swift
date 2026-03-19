import SwiftUI

struct FocusTodoCollapsedSwipeDemoView: View {
    @State private var animationStartDate = Date()

    private let demoPath: [(row: Int, column: Int)] = [
        (1, 1),
        (1, 2),
        (2, 2),
        (2, 1),
        (2, 0),
        (1, 0),
        (0, 0),
        (0, 1),
        (0, 2),
        (1, 2),
        (1, 1)
    ]

    private let segmentDuration: TimeInterval = 0.46

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                GeometryReader { proxy in
                    let size = min(proxy.size.width, proxy.size.height)
                    let cell = size / 3
                    let segmentCount = max(1, demoPath.count - 1)
                    let totalDuration = segmentDuration * Double(segmentCount)
                    let elapsed = timeline.date.timeIntervalSince(animationStartDate)
                    let cycleTime = elapsed.truncatingRemainder(dividingBy: totalDuration)
                    let currentSegment = min(segmentCount - 1, Int(cycleTime / segmentDuration))
                    let currentSegmentStart = Double(currentSegment) * segmentDuration
                    let linearProgress = (cycleTime - currentSegmentStart) / segmentDuration
                    let easedProgress = smoothStep(linearProgress)
                    let start = demoPath[currentSegment]
                    let end = demoPath[currentSegment + 1]
                    let startPoint = point(for: start, cell: cell)
                    let endPoint = point(for: end, cell: cell)
                    let currentPoint = interpolatedPoint(from: startPoint, to: endPoint, progress: easedProgress)

                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.08))

                        ForEach(1..<3, id: \.self) { index in
                            let offset = CGFloat(index) * cell

                            Path { path in
                                path.move(to: CGPoint(x: offset, y: 0))
                                path.addLine(to: CGPoint(x: offset, y: size))
                            }
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)

                            Path { path in
                                path.move(to: CGPoint(x: 0, y: offset))
                                path.addLine(to: CGPoint(x: size, y: offset))
                            }
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        }

                        Path { path in
                            path.move(to: startPoint)
                            path.addLine(to: currentPoint)
                        }
                        .stroke(
                            Color.accentColor.opacity(0.65),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )

                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.accentColor.opacity(0.18))
                            .frame(width: 58, height: 15)
                            .position(currentPoint)

                        Image(systemName: "arrow.forward")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.accentColor.opacity(0.9))
                            .rotationEffect(directionAngle(from: startPoint, to: endPoint))
                            .position(endPoint)

                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(Circle().fill(Color.accentColor))
                            .shadow(color: Color.black.opacity(0.15), radius: 3, y: 1)
                            .position(currentPoint)
                    }
                    .frame(width: size, height: size)

                    Text("9 positions")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .offset(y: size + 6)
                }
            }
            .frame(width: 160, height: 178)
            .frame(maxWidth: .infinity, alignment: .center)
            .onAppear {
                animationStartDate = .now
            }

            HStack {
                Text("L/R: columns")
                Spacer()
                Text("U/D: rows")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
    }

    private func point(for position: (row: Int, column: Int), cell: CGFloat) -> CGPoint {
        CGPoint(
            x: (CGFloat(position.column) + 0.5) * cell,
            y: (CGFloat(position.row) + 0.5) * cell
        )
    }

    private func interpolatedPoint(from start: CGPoint, to end: CGPoint, progress: Double) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }

    private func directionAngle(from start: CGPoint, to end: CGPoint) -> Angle {
        Angle(radians: atan2(end.y - start.y, end.x - start.x))
    }

    private func smoothStep(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }
}
