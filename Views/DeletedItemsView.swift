//
//  DeletedItemsView.swift
//  Fotoz
//

import SwiftUI
import UIKit

struct DeletedItemsView: View {
    @Bindable var viewModel: LibraryViewModel
    @AppStorage("gridColumnsValue") private var columnsValue = 3.0
    @State private var showEmptyConfirmation = false
    @State private var showDeleteSelectedConfirmation = false
    @State private var imageToOpen: DeletedImage?
    @State private var minRating: Int?
    @State private var selectedIDs: Set<LibraryImage.ID> = []
    @State private var isSelecting = false

    private let contentSidePadding: CGFloat = 16

    private var resolvedColumnsPerRow: Int {
        min(max(Int(columnsValue.rounded()), 3), 6)
    }

    private var filteredDeletedImages: [DeletedImage] {
        viewModel.deletedImages.filter { $0.image.matches(minRating: minRating) }
    }

    private var deletedLibraryImages: [LibraryImage] {
        filteredDeletedImages.map(\.image)
    }

    private var selectedDeletedImages: [DeletedImage] {
        filteredDeletedImages.filter { selectedIDs.contains($0.image.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ChromeNavHeader(title: "Deleted Items") {
                if isSelecting {
                    Button("Cancel") { exitSelection() }
                        .font(.body.weight(.semibold))
                        .buttonStyle(.plain)
                        .frame(minWidth: 44, minHeight: 44)
                } else {
                    Menu {
                        if !filteredDeletedImages.isEmpty {
                            Button {
                                isSelecting = true
                            } label: {
                                Label("Select", systemImage: "checkmark.circle")
                            }
                        }

                        Button {
                            viewModel.restoreAllDeletedImages()
                        } label: {
                            Label("Restore all", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(viewModel.deletedImages.isEmpty)

                        Button(role: .destructive) {
                            showEmptyConfirmation = true
                        } label: {
                            Label("Delete all", systemImage: "trash")
                        }
                        .disabled(viewModel.deletedImages.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: ChromeMetrics.iconSize, weight: ChromeMetrics.iconWeight))
                            .foregroundStyle(.primary)
                            .frame(width: ChromeMetrics.hitSize, height: ChromeMetrics.hitSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.deletedImages.isEmpty)
                    .opacity(viewModel.deletedImages.isEmpty ? 0.35 : 1)
                    .accessibilityLabel("Menu")
                }
            }

            Group {
                if viewModel.deletedImages.isEmpty {
                    ContentUnavailableView {
                        Label("No Deleted Items", systemImage: "trash")
                    } description: {
                        Text("Deleted photos stay here for 7 days, then are deleted forever.")
                    }
                } else {
                    VStack(spacing: 0) {
                        RatingFilterBar(minRating: $minRating)
                            .padding(.top, 8)
                            .padding(.bottom, 10)

                        Divider()
                            .padding(.bottom, 10)

                        if filteredDeletedImages.isEmpty {
                            if let minRating {
                                RatingFilterEmptyState(rating: minRating)
                            } else {
                                ContentUnavailableView {
                                    Label("No Photos", systemImage: "line.3.horizontal.decrease.circle")
                                } description: {
                                    Text("Clear the rating filter to see all deleted photos.")
                                }
                            }
                        } else {
                            ScrollView {
                                ImageGridView(
                                    viewModel: viewModel,
                                    images: deletedLibraryImages,
                                    emptyTitle: "No Deleted Items",
                                    emptySystemImage: "trash",
                                    columnsPerRow: resolvedColumnsPerRow,
                                    pageBackground: Color(.systemGroupedBackground),
                                    resolveUIImage: { viewModel.trashUIImage(for: $0) },
                                    menuStyle: .trash,
                                    selectedIDs: $selectedIDs,
                                    isSelecting: isSelecting,
                                    onOpen: { image in
                                        imageToOpen = filteredDeletedImages.first { $0.image.id == image.id }
                                    },
                                    onRestore: { image in
                                        if let deleted = filteredDeletedImages.first(where: { $0.image.id == image.id }) {
                                            viewModel.restoreDeletedImage(deleted)
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    },
                                    onDeleteForever: { image in
                                        if let deleted = filteredDeletedImages.first(where: { $0.image.id == image.id }) {
                                            viewModel.permanentlyDeleteDeletedImage(deleted)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }
                                    }
                                )
                                .animation(
                                    .spring(response: 0.52, dampingFraction: 0.86),
                                    value: resolvedColumnsPerRow
                                )
                                .padding(.bottom, isSelecting ? 8 : 72)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, contentSidePadding)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if !filteredDeletedImages.isEmpty, !isSelecting {
                GridColumnsBar(value: $columnsValue)
                    .padding(.bottom, 16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionDock
            }
        }
        .alert("Are you sure?", isPresented: $showEmptyConfirmation) {
            Button("Yes", role: .destructive) {
                viewModel.emptyDeletedImages()
            }
            Button("No", role: .cancel) {}
        } message: {
            Text("All deleted photos will be permanently deleted and can’t be restored.")
        }
        .alert("Delete Forever?", isPresented: $showDeleteSelectedConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedForever()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let count = selectedDeletedImages.count
            Text(
                count == 1
                    ? "This photo will be permanently deleted and can’t be restored."
                    : "These \(count) photos will be permanently deleted and can’t be restored."
            )
        }
        .fullScreenCover(item: $imageToOpen) { deleted in
            TrashFullScreenImageView(
                viewModel: viewModel,
                images: deletedLibraryImages,
                startID: deleted.image.id
            )
        }
        .onAppear {
            if columnsValue < 3 || columnsValue > 6 {
                columnsValue = 3
            }
            viewModel.refreshDeletedImages()
        }
        .onChange(of: viewModel.deletedImages.map(\.id)) { _, _ in
            selectedIDs = selectedIDs.intersection(Set(deletedLibraryImages.map(\.id)))
            if viewModel.deletedImages.isEmpty {
                exitSelection()
            }
        }
    }

    private var selectionDock: some View {
        let hasSelection = !selectedIDs.isEmpty

        return HStack(spacing: 10) {
            selectionDockButton(
                title: "Restore",
                systemImage: "arrow.uturn.backward",
                foreground: .primary,
                background: Color(.secondarySystemGroupedBackground)
            ) {
                restoreSelected()
            }
            .disabled(!hasSelection)

            selectionDockButton(
                title: "Delete",
                systemImage: "trash",
                foreground: .white,
                background: Color.appRed
            ) {
                showDeleteSelectedConfirmation = true
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

    private func exitSelection() {
        isSelecting = false
        selectedIDs = []
    }

    private func restoreSelected() {
        let selected = selectedDeletedImages
        guard !selected.isEmpty else { return }
        for deleted in selected {
            viewModel.restoreDeletedImage(deleted)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        exitSelection()
    }

    private func deleteSelectedForever() {
        let selected = selectedDeletedImages
        guard !selected.isEmpty else { return }
        for deleted in selected {
            viewModel.permanentlyDeleteDeletedImage(deleted)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        exitSelection()
    }
}

/// Fullscreen viewer for trash items — reads thumbnails from the trash folder.
private struct TrashFullScreenImageView: View {
    @Bindable var viewModel: LibraryViewModel
    let images: [LibraryImage]
    private let openingID: LibraryImage.ID
    @State private var currentID: LibraryImage.ID?
    @State private var didSettleOpening = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: LibraryViewModel, images: [LibraryImage], startID: LibraryImage.ID) {
        self.viewModel = viewModel
        self.images = images
        self.openingID = startID
        _currentID = State(initialValue: startID)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(images) { image in
                        ZStack {
                            Color.black
                            if let uiImage = viewModel.trashUIImage(for: image) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .containerRelativeFrame([.horizontal, .vertical])
                        .background(Color.black)
                        .id(image.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID)
            .scrollIndicators(.hidden)
            .ignoresSafeArea()
            .onChange(of: currentID) { _, newID in
                guard !didSettleOpening, newID != openingID else { return }
                currentID = openingID
            }
            .task(id: openingID) {
                currentID = openingID
                await Task.yield()
                try? await Task.sleep(for: .milliseconds(32))
                if images.first?.id != openingID {
                    currentID = nil
                    await Task.yield()
                    currentID = openingID
                }
                didSettleOpening = true
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: ChromeMetrics.iconSize, weight: ChromeMetrics.iconWeight))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                            .frame(width: ChromeMetrics.hitSize, height: ChromeMetrics.hitSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")

                    Spacer()
                }
                .padding(.horizontal, ChromeMetrics.horizontalPadding)
                .padding(.top, 8)

                Spacer()
            }
        }
        .statusBarHidden(true)
        .onAppear {
            OrientationLock.beginFullscreenAllowingLandscape()
        }
        .onDisappear {
            OrientationLock.endFullscreen()
        }
    }
}
