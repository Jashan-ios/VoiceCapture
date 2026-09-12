import SwiftUI
import SwiftData

struct CaptureListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]

    var body: some View {
        List {
            ForEach(captures) { capture in
                NavigationLink(value: capture) {
                    row(for: capture)
                }
                .transition(.slide.combined(with: .opacity))
            }
            .onDelete(perform: delete)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: captures.count)
        .overlay {
            if captures.isEmpty {
                ContentUnavailableView(
                    "No Captures",
                    systemImage: "mic.slash",
                    description: Text("Record your first voice capture to see it here.")
                )
                .transition(.opacity)
            }
        }
    }

    private func row(for capture: Capture) -> some View {
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
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(capture.createdAt, style: .relative)

                    if !capture.tasks.isEmpty {
                        Text("\(capture.tasks.count) task\(capture.tasks.count == 1 ? "" : "s")")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let capture = captures[index]
            let url = AudioRecorder.documentsDirectory.appendingPathComponent(capture.audioFilename)
            try? FileManager.default.removeItem(at: url)
            modelContext.delete(capture)
        }
    }
}
