//
//  LibraryViewModel.swift
//  Fotoz
//

import Foundation
import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
@Observable
final class LibraryViewModel {
    static let minFolderNameLength = 3
    static let maxFolderNameLength = 10

    private(set) var folders: [Folder] = []
    private(set) var images: [LibraryImage] = []
    private(set) var deletedImages: [DeletedImage] = []
    /// Wrong / empty welcome password: uses a separate on-disk decoy library.
    private(set) var isDecoySession = false
    var errorMessage: String?
    var infoMessage: String?
    var allowsAutomaticClipboardImport = false
    var wantsClipboardImportPrompt = false

    private let decoyStore = ImageLibraryStore.decoy
    private var store: ImageLibraryStore

    init(store: ImageLibraryStore? = nil) {
        self.store = store ?? .shared
        reload()
        ensureDefaultFolder()
    }

    var firstFolder: Folder? {
        folders.first
    }

    /// Switch to the persistent decoy library (wrong / empty password).
    func enterDecoySession() {
        isDecoySession = true
        store = decoyStore
        wantsClipboardImportPrompt = false
        allowsAutomaticClipboardImport = false
        errorMessage = nil
        reload()
    }

    func reload() {
        let snapshot = store.load()
        folders = snapshot.folders.sorted { $0.createdAt > $1.createdAt }
        images = snapshot.images.sorted { $0.createdAt > $1.createdAt }
        refreshDeletedImages()
    }

    func refreshDeletedImages() {
        deletedImages = store.loadDeletedImages()
    }

    /// Disk bytes used by active library images.
    var libraryBytesOnDisk: Int64 {
        store.directorySize(at: store.imagesDirectoryURL)
    }

    /// Disk bytes used by trash.
    var trashBytesOnDisk: Int64 {
        store.directorySize(at: store.trashDirectoryURL)
    }

    @discardableResult
    func ensureDefaultFolder() -> Folder {
        if folders.isEmpty {
            let folder = Folder(name: "Sample")
            folders = [folder]
            persist()
        }

        migrateOrphanImagesIfNeeded()
        return folders[0]
    }

    func folder(with id: UUID) -> Folder? {
        folders.first(where: { $0.id == id })
    }

    func images(in folderID: UUID) -> [LibraryImage] {
        images.filter { $0.folderID == folderID }
    }

    /// Most recently saved photos across the library (Home).
    func recentImages(limit: Int = 20) -> [LibraryImage] {
        Array(images.prefix(limit))
    }

    func imageCount(in folderID: UUID) -> Int {
        images.filter { $0.folderID == folderID }.count
    }

    func coverImages(in folderID: UUID, limit: Int = 4) -> [UIImage] {
        Array(
            images(in: folderID)
                .compactMap { store.loadUIImage(for: $0) }
                .prefix(limit)
        )
    }

    func uiImage(for image: LibraryImage) -> UIImage? {
        store.loadUIImage(for: image)
    }

    func fileURL(for image: LibraryImage) -> URL {
        store.fileURL(for: image)
    }

    // MARK: - Folders

    func folderNameExists(_ name: String, excludingFolderID: UUID? = nil) -> Bool {
        let normalized = Self.normalizedFolderName(name).lowercased()
        guard !normalized.isEmpty else { return false }
        return folders.contains { folder in
            if let excludingFolderID, folder.id == excludingFolderID {
                return false
            }
            return folder.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
    }

    static func normalizedFolderName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxFolderNameLength else { return trimmed }
        return String(trimmed.prefix(maxFolderNameLength))
    }

    @discardableResult
    func createFolder(named name: String) -> Folder? {
        let trimmed = Self.normalizedFolderName(name)
        guard trimmed.count >= Self.minFolderNameLength else { return nil }
        guard !folderNameExists(trimmed) else { return nil }
        let folder = Folder(name: trimmed)
        folders.insert(folder, at: 0)
        persist()
        return folder
    }

    @discardableResult
    func renameFolder(_ folder: Folder, to name: String) -> Bool {
        let trimmed = Self.normalizedFolderName(name)
        guard trimmed.count >= Self.minFolderNameLength else { return false }
        guard !folderNameExists(trimmed, excludingFolderID: folder.id) else { return false }
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return false }
        folders[index].name = trimmed
        persist()
        return true
    }

    func deleteFolder(_ folder: Folder, deleteImages: Bool) {
        if folders.count == 1, folders.first?.id == folder.id {
            errorMessage = "You need at least one album."
            return
        }

        if deleteImages {
            let doomed = images.filter { $0.folderID == folder.id }
            moveImagesToTrash(doomed)
        } else if let destinationID = folders.first(where: { $0.id != folder.id })?.id {
            for index in images.indices where images[index].folderID == folder.id {
                images[index].folderID = destinationID
            }
        }

        folders.removeAll { $0.id == folder.id }
        persist()
    }

    // MARK: - Images

    func deleteImages(_ selected: [LibraryImage]) {
        moveImagesToTrash(selected)
    }

    func restoreDeletedImage(_ deleted: DeletedImage) {
        do {
            var restored = try store.restoreFromTrash(deleted)
            if restored.folderID == nil || !folders.contains(where: { $0.id == restored.folderID }) {
                restored.folderID = ensureDefaultFolder().id
            }
            images.removeAll { $0.id == restored.id }
            images.insert(restored, at: 0)
            deletedImages.removeAll { $0.id == deleted.id }
            persist()
            infoMessage = "Restored"
        } catch {
            errorMessage = "Couldn't restore that photo."
            refreshDeletedImages()
        }
    }

    func permanentlyDeleteDeletedImage(_ deleted: DeletedImage) {
        do {
            try store.permanentlyDeleteFromTrash(deleted)
            deletedImages.removeAll { $0.id == deleted.id }
        } catch {
            errorMessage = "Couldn't delete that photo forever."
            refreshDeletedImages()
        }
    }

    func emptyDeletedImages() {
        do {
            try store.emptyTrash()
            deletedImages = []
        } catch {
            errorMessage = "Couldn't empty deleted items."
            refreshDeletedImages()
        }
    }

    func restoreAllDeletedImages() {
        let items = deletedImages
        guard !items.isEmpty else { return }
        var restoredAny = false
        for item in items {
            do {
                var restored = try store.restoreFromTrash(item)
                if restored.folderID == nil || !folders.contains(where: { $0.id == restored.folderID }) {
                    restored.folderID = ensureDefaultFolder().id
                }
                images.removeAll { $0.id == restored.id }
                images.insert(restored, at: 0)
                deletedImages.removeAll { $0.id == item.id }
                restoredAny = true
            } catch {
                errorMessage = "Couldn't restore all photos."
                refreshDeletedImages()
                return
            }
        }
        if restoredAny {
            persist()
            infoMessage = "Restored all"
        }
    }

    /// Permanently deletes every album, photo, and Deleted Items entry in the
    /// active library (real or decoy). Password settings clear only for the real library.
    func resetApp() {
        do {
            try store.resetAllLibraryData()
            folders = []
            images = []
            deletedImages = []
            wantsClipboardImportPrompt = false
            errorMessage = nil
            if !isDecoySession {
                AppPasswordSettings.clearAll()
            }
            ensureDefaultFolder()
            infoMessage = "App reset"
        } catch {
            errorMessage = "Couldn't reset the app."
            reload()
        }
    }

    func trashUIImage(for image: LibraryImage) -> UIImage? {
        store.loadTrashUIImage(for: image)
    }

    private func moveImagesToTrash(_ selected: [LibraryImage]) {
        guard !selected.isEmpty else { return }
        var movedIDs = Set<UUID>()
        for image in selected {
            do {
                try store.moveToTrash(image)
                movedIDs.insert(image.id)
            } catch {
                errorMessage = "Couldn't move a photo to Deleted Items."
            }
        }
        images.removeAll { movedIDs.contains($0.id) }
        persist()
        refreshDeletedImages()
    }

    func moveImages(_ selected: [LibraryImage], to folderID: UUID) {
        guard folders.contains(where: { $0.id == folderID }) else { return }
        let ids = Set(selected.map(\.id))
        for index in images.indices where ids.contains(images[index].id) {
            images[index].folderID = folderID
        }
        persist()
        infoMessage = "Moved to album"
    }

    func renameImage(_ image: LibraryImage, sourceLabel: String) {
        let trimmed = sourceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = images.firstIndex(where: { $0.id == image.id }) else { return }
        images[index].sourceLabel = trimmed.isEmpty ? nil : trimmed
        persist()
    }

    func setRating(for imageID: UUID, rating: Int?) {
        guard let index = images.firstIndex(where: { $0.id == imageID }) else { return }
        images[index].applyRating(rating)
        persist()
    }

    func image(with id: UUID) -> LibraryImage? {
        images.first(where: { $0.id == id })
    }

    // MARK: - Clipboard

    var canPasteFromClipboard: Bool {
        ClipboardImageService.hasImage
    }

    func offerClipboardImportIfNeeded() {
        guard allowsAutomaticClipboardImport else { return }
        // Require a real image on the pasteboard, not just any clipboard content.
        guard ClipboardImageService.hasImage else { return }
        guard ClipboardImageService.shouldOfferClipboardImport else { return }
        guard !wantsClipboardImportPrompt else { return }
        wantsClipboardImportPrompt = true
    }

    func skipClipboardImportPrompt() {
        wantsClipboardImportPrompt = false
        ClipboardImageService.markClipboardOfferSkipped()
    }

    func pasteFromClipboard(into folderID: UUID) {
        wantsClipboardImportPrompt = false
        guard let data = ClipboardImageService.imageData() else {
            errorMessage = "No image found on the clipboard."
            return
        }
        ClipboardImageService.markClipboardImported()
        importData(data, folderID: folderID, sourceLabel: "Pasted", preferredExtension: "png")
    }

    // MARK: - Import

    func importPickedPhotos(_ items: [PhotosPickerItem], into folderID: UUID) async {
        guard !items.isEmpty else { return }
        var imported = 0
        var hadDuplicate = false
        for item in items {
            do {
                if let transferred = try await item.loadTransferable(type: ImportedImageData.self) {
                    try appendImportedData(
                        transferred.data,
                        folderID: folderID,
                        sourceLabel: "Photos",
                        preferredExtension: nil
                    )
                    imported += 1
                }
            } catch ImageLibraryStoreError.duplicateImage {
                hadDuplicate = true
            } catch {
                errorMessage = "Couldn't import one of the photos."
            }
        }
        if imported > 0 {
            persist()
            infoMessage = imported == 1 ? "Imported 1 photo" : "Imported \(imported) photos"
        } else if hadDuplicate {
            errorMessage = ImageLibraryStoreError.duplicateImage.localizedDescription
        }
    }

    func importFileURLs(_ urls: [URL], into folderID: UUID) {
        var imported = 0
        var hadDuplicate = false
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                let ext = url.pathExtension
                try appendImportedData(
                    data,
                    folderID: folderID,
                    sourceLabel: url.lastPathComponent,
                    preferredExtension: ext
                )
                imported += 1
            } catch ImageLibraryStoreError.duplicateImage {
                hadDuplicate = true
            } catch {
                errorMessage = "Couldn't import \(url.lastPathComponent)."
            }
        }
        if imported > 0 {
            persist()
            infoMessage = imported == 1 ? "Imported 1 file" : "Imported \(imported) files"
        } else if hadDuplicate {
            errorMessage = ImageLibraryStoreError.duplicateImage.localizedDescription
        }
    }

    func saveToPhotos(_ image: LibraryImage) async {
        guard let uiImage = store.loadUIImage(for: image) else {
            errorMessage = ImageLibraryStoreError.missingFile.localizedDescription
            return
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            errorMessage = "Photo Library access is required to save images."
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }
            infoMessage = "Saved to Photos"
        } catch {
            errorMessage = "Couldn't save to Photos."
        }
    }

    // MARK: - Private

    private func importData(
        _ data: Data,
        folderID: UUID,
        sourceLabel: String?,
        preferredExtension: String?
    ) {
        do {
            try appendImportedData(data, folderID: folderID, sourceLabel: sourceLabel, preferredExtension: preferredExtension)
            persist()
            infoMessage = "Image added"
        } catch ImageLibraryStoreError.duplicateImage {
            errorMessage = ImageLibraryStoreError.duplicateImage.localizedDescription
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't import image."
        }
    }

    private func appendImportedData(
        _ data: Data,
        folderID: UUID,
        sourceLabel: String?,
        preferredExtension: String?
    ) throws {
        let image = try store.importImageData(
            data,
            folderID: folderID,
            sourceLabel: sourceLabel,
            preferredExtension: preferredExtension,
            existingImages: images
        )
        images.insert(image, at: 0)
    }

    private func migrateOrphanImagesIfNeeded() {
        guard let destinationID = folders.first?.id else { return }
        var changed = false
        for index in images.indices {
            if images[index].folderID == nil || !folders.contains(where: { $0.id == images[index].folderID }) {
                images[index].folderID = destinationID
                changed = true
            }
        }
        if changed {
            persist()
        }
    }

    private func persist() {
        do {
            try store.save(LibrarySnapshot(folders: folders, images: images))
        } catch {
            errorMessage = "Couldn't save library changes."
        }
    }
}
