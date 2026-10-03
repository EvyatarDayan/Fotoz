//
//  ImageLibraryStore.swift
//  Fotoz
//

import Foundation
import UIKit

enum ImageLibraryStoreError: LocalizedError {
    case invalidImageData
    case writeFailed
    case missingFile
    case duplicateImage

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Couldn't read that image."
        case .writeFailed:
            return "Couldn't save the image."
        case .missingFile:
            return "Image file is missing."
        case .duplicateImage:
            return "This image is already in your library."
        }
    }
}

final class ImageLibraryStore {
    /// Real library (correct password).
    static let shared = ImageLibraryStore(directoryName: "FotozLibrary")
    /// Decoy library (wrong / empty password) — fully functional, separate on disk.
    static let decoy = ImageLibraryStore(directoryName: "FotozLibraryDecoy")

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let directoryName: String

    var rootURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    var imagesDirectoryURL: URL {
        rootURL.appendingPathComponent("Images", isDirectory: true)
    }

    var trashDirectoryURL: URL {
        rootURL.appendingPathComponent("Trash", isDirectory: true)
    }

    private var catalogURL: URL {
        rootURL.appendingPathComponent("catalog.json")
    }

    private var trashManifestURL: URL {
        rootURL.appendingPathComponent("trash.json")
    }

    private init(directoryName: String) {
        self.directoryName = directoryName
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        ensureDirectoriesExist()
    }

    func load() -> LibrarySnapshot {
        ensureDirectoriesExist()
        guard fileManager.fileExists(atPath: catalogURL.path) else {
            return .empty
        }
        do {
            let data = try Data(contentsOf: catalogURL)
            var snapshot = try decoder.decode(LibrarySnapshot.self, from: data)
            snapshot.images = snapshot.images.map { image in
                guard image.byteSize == nil else { return image }
                var updated = image
                updated.byteSize = fileSize(for: image)
                return updated
            }
            return snapshot
        } catch {
            return .empty
        }
    }

    func save(_ snapshot: LibrarySnapshot) throws {
        ensureDirectoriesExist()
        let data = try encoder.encode(snapshot)
        try data.write(to: catalogURL, options: [.atomic])
    }

    func fileURL(for image: LibraryImage) -> URL {
        imagesDirectoryURL.appendingPathComponent(image.fileName)
    }

    func trashFileURL(for image: LibraryImage) -> URL {
        trashDirectoryURL.appendingPathComponent(image.fileName)
    }

    func fileSize(for image: LibraryImage) -> Int64? {
        if let byteSize = image.byteSize {
            return byteSize
        }
        let url = fileURL(for: image)
        guard let size = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber else {
            return nil
        }
        return size.int64Value
    }

    func loadUIImage(for image: LibraryImage) -> UIImage? {
        let url = fileURL(for: image)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadTrashUIImage(for image: LibraryImage) -> UIImage? {
        let url = trashFileURL(for: image)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Same approach as Veedeo’s duration+size check: match stored byte size + source name.
    func existingDuplicate(
        byteSize: Int64,
        sourceLabel: String?,
        in images: [LibraryImage]
    ) -> LibraryImage? {
        let normalizedName = Self.normalizedSourceName(sourceLabel)
        return images.first { image in
            let existingSize = fileSize(for: image)
            guard let existingSize, existingSize == byteSize else { return false }
            return Self.normalizedSourceName(image.sourceLabel) == normalizedName
        }
    }

    @discardableResult
    func importImageData(
        _ data: Data,
        folderID: UUID?,
        sourceLabel: String?,
        preferredExtension: String? = nil,
        existingImages: [LibraryImage] = []
    ) throws -> LibraryImage {
        guard let uiImage = UIImage(data: data) else {
            throw ImageLibraryStoreError.invalidImageData
        }

        let id = UUID()
        let ext = resolvedExtension(for: data, preferred: preferredExtension)
        let fileName = "\(id.uuidString).\(ext)"
        let destination = imagesDirectoryURL.appendingPathComponent(fileName)

        let payload: Data
        if ext == "png", let png = uiImage.pngData() {
            payload = png
        } else if let jpeg = uiImage.jpegData(compressionQuality: 0.92) {
            payload = jpeg
        } else {
            throw ImageLibraryStoreError.writeFailed
        }

        let byteSize = Int64(payload.count)
        if existingDuplicate(byteSize: byteSize, sourceLabel: sourceLabel, in: existingImages) != nil {
            throw ImageLibraryStoreError.duplicateImage
        }

        do {
            try payload.write(to: destination, options: [.atomic])
        } catch {
            throw ImageLibraryStoreError.writeFailed
        }

        return LibraryImage(
            id: id,
            fileName: fileName,
            folderID: folderID,
            sourceLabel: sourceLabel,
            byteSize: byteSize
        )
    }

    func deleteImageFile(_ image: LibraryImage) {
        let url = fileURL(for: image)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Trash (7-day retention)

    func moveToTrash(_ image: LibraryImage) throws {
        ensureDirectoriesExist()
        let source = fileURL(for: image)
        let destination = trashFileURL(for: image)
        try moveFileIfNeeded(from: source, to: destination)

        var trash = loadTrashManifest()
        trash.removeAll { $0.id == image.id }
        trash.insert(DeletedImage(image: image, deletedAt: .now), at: 0)
        try saveTrashManifest(trash)
    }

    func loadDeletedImages() -> [DeletedImage] {
        purgeExpiredTrash()
    }

    func restoreFromTrash(_ deleted: DeletedImage) throws -> LibraryImage {
        ensureDirectoriesExist()
        let restored = deleted.image
        try moveFileIfNeeded(from: trashFileURL(for: restored), to: fileURL(for: restored))

        var trash = loadTrashManifest()
        trash.removeAll { $0.id == deleted.id }
        try saveTrashManifest(trash)
        return restored
    }

    func permanentlyDeleteFromTrash(_ deleted: DeletedImage) throws {
        try? fileManager.removeItem(at: trashFileURL(for: deleted.image))
        var trash = loadTrashManifest()
        trash.removeAll { $0.id == deleted.id }
        try saveTrashManifest(trash)
    }

    func emptyTrash() throws {
        let trash = loadTrashManifest()
        for item in trash {
            try? fileManager.removeItem(at: trashFileURL(for: item.image))
        }
        try saveTrashManifest([])
    }

    /// Permanently wipes albums, active images, and Deleted Items from disk.
    func resetAllLibraryData() throws {
        if fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.removeItem(at: rootURL)
        }
        ensureDirectoriesExist()
        try save(.empty)
        try saveTrashManifest([])
    }

    func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values?.isRegularFile == true else { continue }
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    static func normalizedSourceName(_ name: String?) -> String {
        (name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func purgeExpiredTrash() -> [DeletedImage] {
        let trash = loadTrashManifest()
        let kept = trash.filter { !$0.isExpired }
        let expired = trash.filter(\.isExpired)

        for item in expired {
            try? fileManager.removeItem(at: trashFileURL(for: item.image))
        }

        if kept.count != trash.count {
            try? saveTrashManifest(kept)
        }
        return kept.sorted { $0.deletedAt > $1.deletedAt }
    }

    private func loadTrashManifest() -> [DeletedImage] {
        guard fileManager.fileExists(atPath: trashManifestURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: trashManifestURL)
            return try decoder.decode([DeletedImage].self, from: data)
        } catch {
            return []
        }
    }

    private func saveTrashManifest(_ trash: [DeletedImage]) throws {
        ensureDirectoriesExist()
        let data = try encoder.encode(trash)
        try data.write(to: trashManifestURL, options: [.atomic])
    }

    private func moveFileIfNeeded(from source: URL, to destination: URL) throws {
        guard fileManager.fileExists(atPath: source.path) else { return }
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: source, to: destination)
    }

    private func ensureDirectoriesExist() {
        try? fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: trashDirectoryURL, withIntermediateDirectories: true)
    }

    private func resolvedExtension(for data: Data, preferred: String?) -> String {
        if let preferred {
            let cleaned = preferred.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if ["png", "jpg", "jpeg", "heic", "webp", "gif"].contains(cleaned) {
                return cleaned == "jpeg" ? "jpg" : cleaned
            }
        }

        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }
        return "jpg"
    }
}
