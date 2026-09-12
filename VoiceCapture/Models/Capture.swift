import Foundation
import SwiftData

@Model
final class Capture {
    var id: UUID
    var createdAt: Date
    var audioFilename: String
    var transcript: String
    var summary: String
    var tasks: [String]
    var didStructure: Bool

    init(
        audioFilename: String,
        transcript: String,
        summary: String = "",
        tasks: [String] = [],
        didStructure: Bool = false
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.audioFilename = audioFilename
        self.transcript = transcript
        self.summary = summary
        self.tasks = tasks
        self.didStructure = didStructure
    }
}
