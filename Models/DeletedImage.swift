//
//  DeletedImage.swift
//  Fotoz
//

import Foundation

struct DeletedImage: Identifiable, Codable, Hashable {
    let image: LibraryImage
    let deletedAt: Date

    var id: UUID { image.id }

    static let retentionDays = 7

    var expiresAt: Date {
        Calendar.current.date(byAdding: .day, value: Self.retentionDays, to: deletedAt) ?? deletedAt
    }

    var daysRemaining: Int {
        let remaining = expiresAt.timeIntervalSinceNow
        guard remaining > 0 else { return 0 }
        return Int(ceil(remaining / 86_400))
    }

    var isExpired: Bool {
        Date() >= expiresAt
    }
}
