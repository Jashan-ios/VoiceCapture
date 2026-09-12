import AVFoundation
import SwiftData
import UIKit

@Observable
final class CaptureViewModel {
    private(set) var state: CaptureState = .idle
    private let audioRecorder = AudioRecorder()
    private let transcriber = Transcriber()
    private let structurer: any Structuring = ClaudeStructurer(
        backendURL: AppConfig.backendURL,
        sharedSecret: AppConfig.backendSharedSecret
    )
    private(set) var currentFilename: String?
    private(set) var transcript: String?
    private(set) var result: CaptureResult?
    private(set) var secondsElapsed: Int = 0

    private var timerTask: Task<Void, Never>?
    private var interruptionTask: Task<Void, Never>?
    private var pendingModelContext: ModelContext?

    var amplitude: Float { audioRecorder.amplitude }

    func recordButtonTapped(modelContext: ModelContext) async {
        switch state {
        case .idle, .done, .failed:
            await startRecording(modelContext: modelContext)
        case .recording:
            await stopAndProcess(modelContext: modelContext)
        default:
            break
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Recording

    private func startRecording(modelContext: ModelContext) async {
        // Check microphone permission
        let micPermission = AVAudioApplication.shared.recordPermission
        switch micPermission {
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            guard granted else {
                state = .failed("Microphone access denied.")
                return
            }
        case .denied:
            state = .failed("Microphone access denied.")
            return
        case .granted:
            break
        @unknown default:
            break
        }

        // Check on-device model availability
        let transcriberAvailable = await transcriber.isAvailable
        if !transcriberAvailable {
            state = .failed("On-device speech model is downloading. Please wait and try again.")
            return
        }

        do {
            transcript = nil
            result = nil
            secondsElapsed = 0
            pendingModelContext = modelContext

            let filename = try audioRecorder.startRecording()
            currentFilename = filename
            state = .recording

            startTimer()
            observeInterruption(modelContext: modelContext)
        } catch {
            state = .failed("Recording failed: \(error.localizedDescription)")
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                secondsElapsed += 1
            }
        }
    }

    private func observeInterruption(modelContext: ModelContext) {
        interruptionTask?.cancel()
        interruptionTask = Task {
            let notifications = NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification
            )
            for await notification in notifications {
                guard !Task.isCancelled, state == .recording else { return }

                let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                if typeValue == AVAudioSession.InterruptionType.began.rawValue {
                    await stopAndProcess(modelContext: modelContext)
                    return
                }
            }
        }
    }

    // MARK: - Processing

    private func stopAndProcess(modelContext: ModelContext) async {
        timerTask?.cancel()
        timerTask = nil
        interruptionTask?.cancel()
        interruptionTask = nil
        audioRecorder.stopRecording()

        guard let filename = currentFilename else {
            state = .failed("No recording file found.")
            return
        }

        let url = AudioRecorder.documentsDirectory.appendingPathComponent(filename)

        // Transcribe
        state = .transcribing

        let text: String
        do {
            text = try await transcriber.transcribe(audioFileURL: url)
            transcript = text
        } catch {
            // Transcription failed — keep audio file, show error
            state = .failed(error.localizedDescription)
            return
        }

        // Structure
        state = .structuring

        var structured: CaptureResult?
        do {
            structured = try await structurer.structure(text)
            result = structured
        } catch {
            // Structuring failed — still save the transcript below
        }

        // Persist — never lose the user's words
        let capture = Capture(
            audioFilename: filename,
            transcript: text,
            summary: structured?.summary ?? "",
            tasks: structured?.tasks ?? [],
            didStructure: structured != nil
        )
        modelContext.insert(capture)

        state = .done
    }
}
