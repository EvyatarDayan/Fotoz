//
//  MoveImagesSheet.swift
//  Fotoz
//

import SwiftUI

struct MoveImagesSheet: View {
    let folders: [Folder]
    let currentFolderID: UUID
    let onSelect: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(folders) { folder in
                    Button {
                        onSelect(folder.id)
                    } label: {
                        HStack {
                            Label(folder.name, systemImage: "folder")
                            Spacer()
                            if currentFolderID == folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.appRed)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Move to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
