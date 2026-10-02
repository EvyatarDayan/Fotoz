//
//  ImageCollectionView.swift
//  Fotoz
//

import PhotosUI
import SwiftUI
import UIKit

struct ImageCollectionView: View {
    @Bindable var viewModel: LibraryViewModel
    let folder: Folder

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @AppStorage("gridColumnsValue") private var columnsValue = 3.0
    @State private var selectedIDs: Set<LibraryImage.ID> = []
    @State private var isSelecting = false
    @State private var viewerImageID: LibraryImage.ID?
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var photosPickerOpenTask: Task<Void, Never>?
    @State private var showMoveSheet = false
    @State private var imagesPendingMove: [LibraryImage] = []
    @State private var sharePayload: SharePayload?
    @State private var minRating: Int?
    @State private var entrance = GridEntranceController()

    private var folderBackground: Color {
        // Match Veedeo’s light gray (`systemGroupedBackground`) in light mode.
        if colorScheme == .dark {
            return allImages.isEmpty ? Color(.systemGroupedBackground) : .black
        }
        return Color(.systemGroupedBackground)
    }

    private var resolvedColumnsPerRow: Int {
        min(max(Int(columnsValue.rounded()), 3), 6)
    }

    private var allImages: [LibraryImage] {
        viewModel.images(in: folder.id)
    }

    private var images: [LibraryImage] {
        allImages.filter { $0.matches(minRating: minRating) }
    }

    private var currentFolder: Folder {
        viewModel.folder(with: folder.id) ?? folder
    }

    /// Shared inset for filter bar and photo grid so their edges line up.
    private let contentSidePadding: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            folderHeader

            VStack(spacing: 0) {
                if !allImages.isEmpty {
                    RatingFilterBar(minRating: $minRating)
                        .padding(.top, 8)
                        .padding(.bottom, 10)

                    Divider()
                        .padding(.bottom, 10)
                }

                Group {
                    if allImages.isEmpty {
                        ContentUnavailableView {
                            Label("Empty Album", systemImage: "folder")
                        } description: {
                            Text("Tap + to add images from Photos or Files, or paste from the clipboard.")
                        }
                    } else if images.isEmpty {
                        if let minRating {
                            RatingFilterEmptyState(rating: minRating)
                        } else {
                            ContentUnavailableView {
                                Label("No Photos", systemImage: "line.3.horizontal.decrease.circle")
                            } description: {
                                Text("Rate photos in fullscreen, or clear the rating filter.")
                            }
                        }
                    } else {
                        ScrollView {
                            let visibleIDs = entrance.visibleIDs
                            let entranceDone = entrance.didFinish
                            ImageGridView(
                                viewModel: viewModel,
                                images: images,
                                emptyTitle: "Empty Album",
                                emptySystemImage: "folder",
                                columnsPerRow: resolvedColumnsPerRow,
                                pageBackground: folderBackground,
                                isItemVisible: { entranceDone || visibleIDs.contains($0.id) },
                                selectedIDs: $selectedIDs,
                                isSelecting: isSelecting,
                                onOpen: { viewerImageID = $0.id },
                                onShare: { share(image: $0) },
                                onMove: { presentMove(for: [$0]) }
                            )
                            .animation(
                                .spring(response: 0.52, dampingFraction: 0.86),
                                value: resolvedColumnsPerRow
                            )
                            .padding(.bottom, isSelecting ? 8 : 72)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, contentSidePadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(folderBackground)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if !images.isEmpty, !isSelecting {
                GridColumnsBar(value: $columnsValue)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionDock
            }
        }
        .onAppear {
            if columnsValue < 3 || columnsValue > 6 {
                columnsValue = 3
            }
            // Folder screen only — never welcome / folders list.
            viewModel.allowsAutomaticClipboardImport = true
            viewModel.offerClipboardImportIfNeeded()
            entrance.playIfNeeded(ids: images.map(\.id))
        }
        .onDisappear {
            viewModel.allowsAutomaticClipboardImport = false
            viewModel.wantsClipboardImportPrompt = false
            entrance.cancel()
        }
        .onChange(of: images.map(\.id)) { _, ids in
            entrance.playIfNeeded(ids: ids)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            guard viewModel.allowsAutomaticClipboardImport else { return }
            viewModel.offerClipboardImportIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard viewModel.allowsAutomaticClipboardImport else { return }
            viewModel.offerClipboardImportIfNeeded()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.allowsAutomaticClipboardImport && viewModel.wantsClipboardImportPrompt },
            set: { if !$0 { viewModel.skipClipboardImportPrompt() } }
        )) {
            ClipboardPastePrompt(
                onImport: {
                    viewModel.pasteFromClipboard(into: folder.id)
                },
                onSkip: {
                    viewModel.skipClipboardImportPrompt()
                }
            )
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $photoPickerItems,
            maxSelectionCount: 30,
            matching: .images
        )
        .onChange(of: photoPickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await viewModel.importPickedPhotos(items, into: folder.id)
                photoPickerItems = []
            }
        }
        .fullScreenCover(item: viewerBinding) { image in
            FullScreenImageView(
                viewModel: viewModel,
                images: images,
                startID: image.id
            )
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveImagesSheet(
                folders: viewModel.folders,
                currentFolderID: folder.id
            ) { destination in
                viewModel.moveImages(imagesPendingMove, to: destination)
                imagesPendingMove = []
                if isSelecting {
                    exitSelection()
                }
                showMoveSheet = false
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
    }

    private var selectionDock: some View {
        let hasSelection = !selectedIDs.isEmpty

        return HStack(spacing: 10) {
            selectionDockButton(
                title: "Move",
                systemImage: "folder",
                foreground: .primary,
                background: Color(.secondarySystemGroupedBackground)
            ) {
                presentMove(for: images.filter { selectedIDs.contains($0.id) })
            }
            .disabled(!hasSelection)

            selectionDockButton(
                title: "Share",
                systemImage: "square.and.arrow.up",
                foreground: .primary,
                background: Color(.secondarySystemGroupedBackground)
            ) {
                shareSelected()
            }
            .disabled(!hasSelection)

            selectionDockButton(
                title: "Delete",
                systemImage: "trash",
                foreground: .white,
                background: Color.appRed
            ) {
                let selected = images.filter { selectedIDs.contains($0.id) }
                viewModel.deleteImages(selected)
                exitSelection()
            }
            .disabled(!hasSelection)
        }
        .opacity(hasSelection ? 1 : 0.45)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func selectionDockButton(
        title: String,
        systemImage: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var folderHeader: some View {
        HStack {
            ChromeIconButton(systemName: "chevron.left", accessibilityLabel: "Back") {
                dismiss()
            }

            Spacer(minLength: 0)

            Text(currentFolder.name)
                .font(.headline)
                .lineLimit(1)

            Spacer(minLength: 0)

            if isSelecting {
                Button("Cancel") { exitSelection() }
                    .font(.body.weight(.semibold))
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
            } else {
                Menu {
                    if !allImages.isEmpty {
                        Button {
                            isSelecting = true
                        } label: {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                    }

                    Button {
                        openPhotosPickerAfterMenuDismiss()
                    } label: {
                        Label("+ From photos", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        viewModel.pasteFromClipboard(into: folder.id)
                    } label: {
                        Label("+ From clipboard", systemImage: "doc.on.clipboard")
                    }
                    .disabled(!viewModel.canPasteFromClipboard)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: ChromeMetrics.iconSize, weight: ChromeMetrics.iconWeight))
                        .foregroundStyle(.primary)
                        .frame(width: ChromeMetrics.hitSize, height: ChromeMetrics.hitSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Menu")
            }
        }
        .padding(.horizontal, ChromeMetrics.horizontalPadding)
        .padding(.bottom, 6)
        .background(folderBackground)
    }

    private var viewerBinding: Binding<LibraryImage?> {
        Binding(
            get: {
                guard let viewerImageID else { return nil }
                return images.first(where: { $0.id == viewerImageID })
            },
            set: { newValue in
                viewerImageID = newValue?.id
            }
        )
    }

    private func openPhotosPickerAfterMenuDismiss() {
        photosPickerOpenTask?.cancel()
        photosPickerOpenTask = Task { @MainActor in
            showPhotosPicker = false
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            showPhotosPicker = true
        }
    }

    private func exitSelection() {
        isSelecting = false
        selectedIDs = []
    }

    private func presentMove(for images: [LibraryImage]) {
        guard !images.isEmpty else { return }
        imagesPendingMove = images
        showMoveSheet = true
    }

    private func shareSelected() {
        let selected = images.filter { selectedIDs.contains($0.id) }
        let payloads: [Any] = selected.compactMap { viewModel.uiImage(for: $0) }
        guard !payloads.isEmpty else { return }
        sharePayload = SharePayload(items: payloads)
    }

    private func share(image: LibraryImage) {
        guard let uiImage = viewModel.uiImage(for: image) else { return }
        sharePayload = SharePayload(items: [uiImage])
    }

}
