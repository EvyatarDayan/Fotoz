//
//  ClipboardPastePrompt.swift
//  Fotoz
//

import SwiftUI

struct ClipboardPastePrompt: View {
    var onImport: () -> Void
    var onSkip: () -> Void

    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Import from clipboard?")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button {
                    importFromClipboard()
                } label: {
                    Text(isImporting ? "Importing…" : "Yes, Import")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(Color.appRed, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isImporting)

                Button("Not Now") {
                    onSkip()
                }
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.secondary)
                .disabled(isImporting)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(errorMessage == nil ? 220 : 260)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    private func importFromClipboard() {
        isImporting = true
        errorMessage = nil

        guard ClipboardImageService.hasImage, ClipboardImageService.imageData() != nil else {
            isImporting = false
            errorMessage = "Nothing to paste. Copy an image first."
            return
        }

        onImport()
    }
}
