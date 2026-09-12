import Foundation

/// Calls your own backend (see /Backend), which holds the Anthropic API key
/// and relays the transcript to Claude for task extraction + summary.
struct ClaudeStructurer: Structuring {
    private let backendURL: URL
    private let sharedSecret: String

    init(backendURL: URL, sharedSecret: String) {
        self.backendURL = backendURL
        self.sharedSecret = sharedSecret
    }

    func structure(_ transcript: String) async throws -> CaptureResult {
        var request = URLRequest(url: backendURL.appendingPathComponent("structure"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sharedSecret, forHTTPHeaderField: "X-App-Secret")
        request.httpBody = try JSONEncoder().encode(["transcript": transcript])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeStructurerError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ClaudeStructurerError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(BackendStructureResponse.self, from: data)
        return CaptureResult(tasks: decoded.tasks, summary: decoded.summary)
    }
}

private struct BackendStructureResponse: Decodable {
    let summary: String
    let tasks: [String]
}

enum ClaudeStructurerError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Received an invalid response from the server."
        case .serverError(let statusCode):
            "Server returned an error (status \(statusCode))."
        }
    }
}
