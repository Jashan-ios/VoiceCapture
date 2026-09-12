import SwiftUI

struct CaptureDetailView: View {
    @Bindable var capture: Capture
    @State private var isEditing = false
    @State private var editedTranscript: String = ""
    @State private var isRestructuring = false
    @State private var appeared = false

    private let structurer: any Structuring = ClaudeStructurer(
        backendURL: AppConfig.backendURL,
        sharedSecret: AppConfig.backendSharedSecret
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                if capture.didStructure {
                    if !capture.tasks.isEmpty {
                        section("Tasks", items: capture.tasks, icon: "checkmark.circle", color: .green)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 15)
                    }
                }

                transcriptSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 25)

                if isRestructuring {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Reprocessing...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
        }
        .navigationTitle("Capture")
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isRestructuring)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareText)
            }
            ToolbarItemGroup(placement: .secondaryAction) {
                Button("Copy", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = shareText
                }
                Button("Edit", systemImage: "pencil") {
                    editedTranscript = capture.transcript
                    isEditing = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            editSheet
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }

    // MARK: - Edit Sheet

    private var editSheet: some View {
        NavigationStack {
            TextEditor(text: $editedTranscript)
                .padding()
                .navigationTitle("Edit Transcript")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isEditing = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            isEditing = false
                            Task { await saveAndRestructure() }
                        }
                        .disabled(editedTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }

    private func saveAndRestructure() async {
        let trimmed = editedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        capture.transcript = trimmed

        isRestructuring = true
        do {
            let result = try await structurer.structure(trimmed)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                capture.summary = result.summary
                capture.tasks = result.tasks
                capture.didStructure = true
            }
        } catch {
            capture.didStructure = false
        }
        isRestructuring = false
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(capture.summary.isEmpty ? "Untitled" : capture.summary)
                .font(.title2.weight(.semibold))

            Text(capture.createdAt, format: .dateTime.month().day().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sections

    private func section(_ title: String, items: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Label(item, systemImage: icon)
                    .font(.body)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(capture.transcript)
                .font(.body)
                .foregroundStyle(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Share

    private var shareText: String {
        var parts: [String] = []

        if !capture.summary.isEmpty {
            parts.append(capture.summary)
            parts.append("")
        }

        if !capture.tasks.isEmpty {
            parts.append("Tasks:")
            for task in capture.tasks {
                parts.append("- \(task)")
            }
            parts.append("")
        }

        parts.append("Transcript:")
        parts.append(capture.transcript)

        return parts.joined(separator: "\n")
    }
}
