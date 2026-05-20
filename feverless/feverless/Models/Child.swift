import Foundation
import SwiftData

@Model
final class Child {
    var id: UUID = UUID()
    var name: String = ""
    var birthDate: Date?
    var avatarEmoji: String = "🧒"
    var createdAt: Date = Date()

    init(name: String, birthDate: Date? = nil, avatarEmoji: String = "🧒") {
        self.id = UUID()
        self.name = name
        self.birthDate = birthDate
        self.avatarEmoji = avatarEmoji
        self.createdAt = Date()
    }
}
