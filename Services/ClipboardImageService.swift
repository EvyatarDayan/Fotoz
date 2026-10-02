//
//  ClipboardImageService.swift
//  Fotoz
//

import UIKit
import UniformTypeIdentifiers

enum ClipboardImageService {
    private static var skippedOfferChangeCount: Int?
    private static var importedChangeCount: Int?

    static var hasImage: Bool {
        UIPasteboard.general.hasImages
            || UIPasteboard.general.data(forPasteboardType: UTType.png.identifier) != nil
            || UIPasteboard.general.data(forPasteboardType: UTType.jpeg.identifier) != nil
            || UIPasteboard.general.data(forPasteboardType: UTType.heic.identifier) != nil
    }

    static var shouldOfferClipboardImport: Bool {
        guard hasImage else { return false }
        let changeCount = UIPasteboard.general.changeCount
        if skippedOfferChangeCount == changeCount { return false }
        if importedChangeCount == changeCount { return false }
        return true
    }

    static func markClipboardOfferSkipped() {
        skippedOfferChangeCount = UIPasteboard.general.changeCount
    }

    static func markClipboardImported() {
        importedChangeCount = UIPasteboard.general.changeCount
    }

    static func imageData() -> Data? {
        let pasteboard = UIPasteboard.general

        if let image = pasteboard.image {
            if let png = image.pngData() {
                return png
            }
            return image.jpegData(compressionQuality: 0.92)
        }

        if let data = pasteboard.data(forPasteboardType: UTType.png.identifier) {
            return data
        }
        if let data = pasteboard.data(forPasteboardType: UTType.jpeg.identifier) {
            return data
        }
        if let data = pasteboard.data(forPasteboardType: UTType.heic.identifier) {
            return data
        }

        return nil
    }
}
