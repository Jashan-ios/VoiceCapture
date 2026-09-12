import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = CaptureViewModel()
    @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]
    @State private var dismissedRecentCaptureID: PersistentIdentifier?

    private var recentCapture: Capture? {
        guard let capture = captures.first, capture.persistentModelID != dismissedRecentCaptureID else {
            return nil
        }
        return capture
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            statusArea

            RecordButton(state: viewModel.state, amplitude: viewModel.amplitude) {
                Task { await viewModel.recordButtonTapped(modelContext: modelContext) }
            }

            if let result = viewModel.result {
                resultView(result)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                        removal: .opacity
                    ))
            }

            Spacer()

            if let recentCapture {
                recentCaptureCard(recentCapture)
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .navigationTitle("VoiceCapture")
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.state)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.state)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.result != nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: recentCapture?.persistentModelID)
    }

    // MARK: - Recent Capture

    private func recentCaptureCard(_ capture: Capture) -> some View {
        NavigationLink(value: capture) {
            HStack(spacing: 12) {
                Circle()
                    .fill(capture.didStructure ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: capture.didStructure ? "checkmark" : "waveform")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(capture.didStructure ? .green : .orange)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(capture.summary.isEmpty ? "Untitled" : capture.summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(capture.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            dismissedRecentCaptureID = capture.persistentModelID
        })
    }

    // MARK: - Status

    private var statusArea: some View {
        VStack(spacing: 8) {
            Text(statusText)
                .font(.headline)
                .foregroundStyle(.secondary)
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.25), value: statusText)

            if viewModel.state == .recording {
                Text(elapsedText)
                    .font(.system(.largeTitle, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.secondsElapsed)
                    .transition(.scale.combined(with: .opacity))
            }

            if case .failed = viewModel.state {
                Button("Open Settings") {
                    viewModel.openSettings()
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var elapsedText: String {
        let m = viewModel.secondsElapsed / 60
        let s = viewModel.secondsElapsed % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Result

    private func resultView(_ result: CaptureResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(result.summary)
                    .font(.headline)

                if !result.tasks.isEmpty {
                    section("Tasks", items: result.tasks, icon: "checkmark.circle")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .frame(maxHeight: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func section(_ title: String, items: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Label(item, systemImage: icon)
                    .font(.body)
            }
        }
    }

    // MARK: - Status Text

    private var statusText: String {
        switch viewModel.state {
        case .idle: "Tap to record"
        case .recording: "Recording..."
        case .transcribing: "Transcribing..."
        case .structuring: "Processing..."
        case .done: "Done"
        case .failed(let message): message
        }
    }
}
