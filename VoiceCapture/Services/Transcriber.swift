import Speech
import AVFoundation

/// Transcribes a recorded audio file entirely on-device using Apple's
/// SpeechAnalyzer / SpeechTranscriber (iOS 26+). Unlike SFSpeechRecognizer,
/// this is designed for long-form audio: the file is streamed into the
/// analyzer in chunks rather than loaded into one giant buffer, so recording
/// length isn't limited by memory or a single-request time cap.
final class Transcriber {
    private let locale: Locale
    private let converter = BufferConverter()

    init(locale: Locale = .current) {
        self.locale = locale
    }

    var isAvailable: Bool {
        get async {
            await SpeechTranscriber.supportedLocales.contains {
                $0.identifier(.bcp47) == locale.identifier(.bcp47)
            }
        }
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        try await ensureModelAvailable(for: transcriber)

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriberError.noCompatibleAudioFormat
        }

        let audioFile = try AVAudioFile(forReading: audioFileURL)

        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

        var segments: [String] = []
        let resultsTask = Task {
            for try await result in transcriber.results where result.isFinal {
                segments.append(String(result.text.characters))
            }
        }

        try await analyzer.start(inputSequence: inputSequence)

        let frameCapacity: AVAudioFrameCount = 4096
        while audioFile.framePosition < audioFile.length {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCapacity) else {
                break
            }
            try audioFile.read(into: buffer, frameCount: frameCapacity)
            guard buffer.frameLength > 0 else { break }

            let converted = try converter.convertBuffer(buffer, to: analyzerFormat)
            inputBuilder.yield(AnalyzerInput(buffer: converted))
        }
        inputBuilder.finish()

        try await analyzer.finalizeAndFinishThroughEndOfInput()
        try await resultsTask.value

        let transcript = segments.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            throw TranscriberError.emptyTranscript
        }
        return transcript
    }

    private func ensureModelAvailable(for transcriber: SpeechTranscriber) async throws {
        guard await SpeechTranscriber.supportedLocales.contains(where: {
            $0.identifier(.bcp47) == locale.identifier(.bcp47)
        }) else {
            throw TranscriberError.localeNotSupported
        }

        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let reserved = await AssetInventory.reservedLocales
        if !reserved.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
            try await AssetInventory.reserve(locale: locale)
        }
    }
}

/// Converts audio buffers between formats, e.g. the recorder's format to
/// whatever format SpeechAnalyzer requires for this device/locale.
private final class BufferConverter {
    enum ConversionError: Error {
        case failedToCreateConverter
        case failedToCreateConversionBuffer
        case conversionFailed(NSError?)
    }

    private var converter: AVAudioConverter?

    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        guard inputFormat != format else { return buffer }

        if converter == nil || converter?.outputFormat != format {
            converter = AVAudioConverter(from: inputFormat, to: format)
            converter?.primeMethod = .none
        }

        guard let converter else {
            throw ConversionError.failedToCreateConverter
        }

        let sampleRateRatio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let scaledInputFrameLength = Double(buffer.frameLength) * sampleRateRatio
        let frameCapacity = AVAudioFrameCount(scaledInputFrameLength.rounded(.up))
        guard let conversionBuffer = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: frameCapacity) else {
            throw ConversionError.failedToCreateConversionBuffer
        }

        var nsError: NSError?
        var bufferProcessed = false
        let status = converter.convert(to: conversionBuffer, error: &nsError) { _, inputStatusPointer in
            if bufferProcessed {
                inputStatusPointer.pointee = .noDataNow
                return nil
            }
            bufferProcessed = true
            inputStatusPointer.pointee = .haveData
            return buffer
        }

        guard status != .error else {
            throw ConversionError.conversionFailed(nsError)
        }

        return conversionBuffer
    }
}

enum TranscriberError: LocalizedError {
    case localeNotSupported
    case noCompatibleAudioFormat
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .localeNotSupported:
            "On-device transcription isn't available for this language on this device."
        case .noCompatibleAudioFormat:
            "Couldn't find a compatible audio format for transcription."
        case .emptyTranscript:
            "No speech detected in the recording."
        }
    }
}
