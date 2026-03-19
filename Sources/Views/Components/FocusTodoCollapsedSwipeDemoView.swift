import SwiftUI

struct FocusTodoCollapsedSwipeDemoView: View {
    @State private var stepIndex = 0
    @State private var demoTask: Task<Void, Never>?

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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                let cell = size / 3
                let currentPoint = point(for: demoPath[stepIndex], cell: cell)

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

                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: cell - 10, height: cell - 10)
                        .position(currentPoint)

                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(Circle().fill(Color.accentColor))
                        .shadow(color: Color.black.opacity(0.15), radius: 3, y: 1)
                        .position(currentPoint)
                }
                .frame(width: size, height: size)
                .animation(.spring(duration: 0.32, bounce: 0.18), value: stepIndex)

                Text("9 positions".localized())
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .offset(y: size + 6)
            }
            .frame(width: 160, height: 178)
            .frame(maxWidth: .infinity, alignment: .center)
            .onAppear {
                startDemoLoop()
            }
            .onDisappear {
                demoTask?.cancel()
                demoTask = nil
            }

            HStack {
                Text("L/R: columns".localized())
                Spacer()
                Text("U/D: rows".localized())
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

    private func startDemoLoop() {
        guard demoTask == nil else { return }

        demoTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(650))
                await MainActor.run {
                    stepIndex = (stepIndex + 1) % demoPath.count
                }
            }
        }
    }
}
