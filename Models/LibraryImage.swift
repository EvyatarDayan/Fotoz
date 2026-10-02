//
//  LibraryImage.swift
//  Fotoz
//

import Foundation

struct LibraryImage: Identifiable, Codable, Hashable {
    let id: UUID
    var fileName: String
    var createdAt: Date
    var folderID: UUID?
    var sourceLabel: String?
    /// Stored file size in bytes — used with sourceLabel for duplicate detection.
    var byteSize: Int64?
    /// User rating from 1…5. Nil means unrated.
    var rating: Int?

    init(
        id: UUID = UUID(),
        fileName: String,
        createdAt: Date = .now,
        folderID: UUID? = nil,
        sourceLabel: String? = nil,
        byteSize: Int64? = nil,
        rating: Int? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.folderID = folderID
        self.sourceLabel = sourceLabel
        self.byteSize = byteSize
        self.rating = rating.map { min(max($0, 1), 5) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, fileName, createdAt, folderID, sourceLabel, byteSize, rating
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fileName = try container.decode(String.self, forKey: .fileName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
        sourceLabel = try container.decodeIfPresent(String.self, forKey: .sourceLabel)
        byteSize = try container.decodeIfPresent(Int64.self, forKey: .byteSize)
        if let decoded = try container.decodeIfPresent(Int.self, forKey: .rating) {
            rating = min(max(decoded, 1), 5)
        } else {
            rating = nil
        }
    }

    /// Exact star match when filtering (same as Veedeo). Nil filter shows all.
    func matches(minRating: Int?) -> Bool {
        guard let minRating else { return true }
        guard let rating else { return false }
        return rating == minRating
    }

    mutating func applyRating(_ rating: Int?) {
        self.rating = rating.map { min(max($0, 1), 5) }
    }
}
