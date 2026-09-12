enum CaptureState: Equatable {
    case idle
    case recording
    case transcribing
    case structuring
    case done
    case failed(String)
}
