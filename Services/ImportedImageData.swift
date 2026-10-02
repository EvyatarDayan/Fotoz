//
//  ImportedImageData.swift
//  Fotoz
//

import CoreTransferable
import UniformTypeIdentifiers

struct ImportedImageData: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            ImportedImageData(data: data)
        }
    }
}
