import AVFoundation

@Observable
final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var meteringTask: Task<Void, Never>?
    private(set) var amplitude: Float = 0

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func startRecording() throws -> String {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        let filename = UUID().uuidString + ".m4a"
        let url = Self.documentsDirectory.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let newRecorder = try AVAudioRecorder(url: url, settings: settings)
        newRecorder.isMeteringEnabled = true
        newRecorder.record()

        recorder = newRecorder
        startMetering()

        return filename
    }

    func stopRecording() {
        meteringTask?.cancel()
        meteringTask = nil
        recorder?.stop()
        recorder = nil
        amplitude = 0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startMetering() {
        meteringTask = Task {
            while !Task.isCancelled {
                guard let recorder else { return }
                recorder.updateMeters()
                let db = recorder.averagePower(forChannel: 0)
                let raw = pow(10, db / 20)
                amplitude += (raw - amplitude) * 0.2
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }
}
