//
//  LibrarySnapshot.swift
//  Fotoz
//

import Foundation

struct LibrarySnapshot: Codable {
    var folders: [Folder]
    var images: [LibraryImage]

    static let empty = LibrarySnapshot(folders: [], images: [])
}
