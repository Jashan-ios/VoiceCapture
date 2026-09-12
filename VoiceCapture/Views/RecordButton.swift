import SwiftUI

struct RecordButton: View {
    let state: CaptureState
    let amplitude: Float
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ripple = false

    private let orbSize: CGFloat = 220

    var body: some View {
        Button(action: action) {
            ZStack {
                // Ripple ring on state change
                Circle()
                    .stroke(stateColor.opacity(ripple ? 0 : 0.4), lineWidth: 1.5)
                    .frame(width: ripple ? orbSize * 1.3 : orbSize * 0.65, height: ripple ? orbSize * 1.3 : orbSize * 0.65)
                    .animation(.easeOut(duration: 0.7), value: ripple)

                orbView
                iconOverlay
            }
            .frame(width: orbSize, height: orbSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(state == .transcribing || state == .structuring)
        .onChange(of: state) {
            ripple = false
            withAnimation { ripple = true }
        }
    }

    // MARK: - Orb

    @ViewBuilder
    private var orbView: some View {
        if reduceMotion {
            Circle()
                .fill(stateColor.opacity(0.1))
                .stroke(stateColor.opacity(0.5), lineWidth: 2)
                .frame(width: orbSize * 0.65, height: orbSize * 0.65)
                .animation(.easeInOut(duration: 0.3), value: state)
        } else if state == .idle {
            TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                orbCanvas(time: context.date.timeIntervalSinceReferenceDate)
            }
        } else if state == .recording || state == .transcribing || state == .structuring {
            TimelineView(.animation) { context in
                orbCanvas(time: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            orbCanvas(time: Date.now.timeIntervalSinceReferenceDate)
        }
    }

    private func orbCanvas(time: Double) -> some View {
        Canvas { gc, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let baseRadius = min(size.width, size.height) / 2 * 0.6

            switch state {
            case .idle:
                drawIdle(in: &gc, center: center, radius: baseRadius, time: time)
            case .recording:
                drawRecording(in: &gc, center: center, radius: baseRadius, time: time)
            case .transcribing, .structuring:
                drawProcessing(in: &gc, center: center, radius: baseRadius, time: time)
            case .done:
                drawDone(in: &gc, center: center, radius: baseRadius, time: time)
            case .failed:
                drawFailed(in: &gc, center: center, radius: baseRadius, time: time)
            }
        }
        .frame(width: orbSize, height: orbSize)
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconOverlay: some View {
        Group {
            switch state {
            case .idle:
                Image(systemName: "mic.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue.opacity(0.9))
            case .recording:
                Image(systemName: "stop.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            case .transcribing, .structuring:
                ProgressView()
                    .tint(.purple)
                    .scaleEffect(1.2)
            case .done:
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: state)
            case .failed:
                Image(systemName: "mic.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: state)
    }

    // MARK: - Color

    private var stateColor: Color {
        switch state {
        case .idle: .blue
        case .recording: .orange
        case .transcribing, .structuring: .purple
        case .done: .green
        case .failed: .red
        }
    }

    // MARK: - Drawing: Idle

    private func drawIdle(in gc: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: Double) {
        // Soft center glow
        let glowBreath = 0.06 + 0.03 * sin(time * 0.5)
        let glowRect = CGRect(x: center.x - radius * 0.6, y: center.y - radius * 0.6,
                              width: radius * 1.2, height: radius * 1.2)
        gc.fill(Circle().path(in: glowRect), with: .color(.blue.opacity(glowBreath)))

        // 3 breathing rings
        for i in 0..<3 {
            let breatheSpeed = 0.6 + Double(i) * 0.15
            let breathe = 1.0 + 0.06 * sin(time * breatheSpeed)
            let r = radius * breathe + CGFloat(i) * 12

            let rotSpeed = 0.3 + Double(i) * 0.2
            let phase = time * rotSpeed
            let lobes = 3 + i
            let wobble: CGFloat = 4 + CGFloat(i) * 2

            let path = ringPath(center: center, radius: r, wobble: wobble, lobes: lobes, phase: phase)
            let opacity = 0.35 - Double(i) * 0.08
            gc.stroke(path, with: .color(.blue.opacity(opacity)), lineWidth: 1.5)
        }
    }

    // MARK: - Drawing: Recording

    private func drawRecording(in gc: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: Double) {
        let amp = CGFloat(amplitude)

        // Pulsing filled core
        let coreRadius = radius * (0.35 + amp * 0.25)
        let coreRect = CGRect(x: center.x - coreRadius, y: center.y - coreRadius,
                              width: coreRadius * 2, height: coreRadius * 2)
        gc.fill(Circle().path(in: coreRect), with: .color(.orange.opacity(0.12 + Double(amp) * 0.15)))

        // Outer glow ring
        let glowRadius = radius * (1.15 + amp * 0.2)
        let glowRect = CGRect(x: center.x - glowRadius, y: center.y - glowRadius,
                              width: glowRadius * 2, height: glowRadius * 2)
        gc.stroke(Circle().path(in: glowRect), with: .color(.orange.opacity(0.1 + Double(amp) * 0.1)),
                  lineWidth: 1)

        // 3 reactive rings
        for i in 0..<3 {
            let r = radius * (1.0 + amp * 0.2) - CGFloat(i) * 8
            let rotSpeed = 1.2 + Double(i) * 0.5
            let phase = time * rotSpeed
            let wobbleAmount: CGFloat = 4 + amp * 16
            let lobes = 4 + i

            let path = ringPath(center: center, radius: r, wobble: wobbleAmount, lobes: lobes, phase: phase)
            let opacity = 0.65 - Double(i) * 0.12
            let lineWidth: CGFloat = 2.5 - CGFloat(i) * 0.4
            gc.stroke(path, with: .color(.orange.opacity(opacity)), lineWidth: lineWidth)
        }
    }

    // MARK: - Drawing: Processing

    private func drawProcessing(in gc: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: Double) {
        let collapsedRadius = radius * 0.5

        // Pulsing center dot
        let dotPulse = 4.0 + 2.0 * sin(time * 3.0)
        let dotRect = CGRect(x: center.x - dotPulse, y: center.y - dotPulse,
                             width: dotPulse * 2, height: dotPulse * 2)
        gc.fill(Circle().path(in: dotRect), with: .color(.purple.opacity(0.5)))

        // 3 counter-rotating arcs
        for i in 0..<3 {
            let direction: Double = i.isMultiple(of: 2) ? 1.0 : -1.0
            let speed = (1.8 + Double(i) * 0.6) * direction
            let start = Angle(radians: time * speed)
            let sweepFraction = 0.3 + 0.15 * sin(time * 1.2 + Double(i) * .pi * 0.67)
            let sweep = Angle(radians: 2 * .pi * sweepFraction)
            let r = collapsedRadius - CGFloat(i) * 10

            var path = Path()
            path.addArc(center: center, radius: r, startAngle: start, endAngle: start + sweep, clockwise: false)

            let lineWidth: CGFloat = 3.5 - CGFloat(i) * 0.5
            gc.stroke(path, with: .color(.purple.opacity(0.65 - Double(i) * 0.1)),
                      style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }

    // MARK: - Drawing: Done

    private func drawDone(in gc: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: Double) {
        // Soft pulsing green glow
        let glowPulse = 0.08 + 0.04 * sin(time * 1.5)
        let glowRect = CGRect(x: center.x - radius * 0.7, y: center.y - radius * 0.7,
                              width: radius * 1.4, height: radius * 1.4)
        gc.fill(Circle().path(in: glowRect), with: .color(.green.opacity(glowPulse)))

        // Static ring
        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        gc.stroke(Circle().path(in: rect), with: .color(.green.opacity(0.5)), lineWidth: 2)
    }

    // MARK: - Drawing: Failed

    private func drawFailed(in gc: inout GraphicsContext, center: CGPoint, radius: CGFloat, time: Double) {
        // Subtle pulse so it doesn't feel dead
        let pulse = 0.4 + 0.1 * sin(time * 2.0)
        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        gc.stroke(Circle().path(in: rect), with: .color(.red.opacity(pulse)), lineWidth: 2)
    }

    // MARK: - Ring Path

    private func ringPath(center: CGPoint, radius: CGFloat, wobble: CGFloat, lobes: Int, phase: Double) -> Path {
        Path { path in
            let steps = 120
            for step in 0...steps {
                let angle = Double(step) / Double(steps) * 2 * .pi
                let r = radius + wobble * CGFloat(sin(Double(lobes) * angle + phase))
                let point = CGPoint(
                    x: center.x + r * cos(angle),
                    y: center.y + r * sin(angle)
                )
                if step == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }
    }
}
