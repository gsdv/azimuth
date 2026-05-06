import Foundation

enum SendStatus: Equatable {
    case idle
    case sending
    case success(at: Date)
    case failure(message: String, at: Date)

    var isSending: Bool {
        if case .sending = self { return true }
        return false
    }
}

struct SendRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var success: Bool
    var statusCode: Int?
    var message: String?
}
