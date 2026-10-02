//
//  FullScreenImageView.swift
//  Fotoz
//

import SwiftUI
import UIKit

struct FullScreenImageView: View {
    @Bindable var viewModel: LibraryViewModel
    let images: [LibraryImage]
    @Environment(\.dismiss) private var dismiss

    @State private var currentID: LibraryImage.ID?
    @State private var showChrome = true
    @State private var sharePayload: SharePayload?
    @State private var showMoveSheet = false
    @State private var showDeleteConfirm = false

    init(viewModel: LibraryViewModel, images: [LibraryImage], startID: LibraryImage.ID) {
        self.viewModel = viewModel
        self.images = images
        _currentID = State(initialValue: startID)
    }

    private var currentImage: LibraryImage? {
        guard let currentID else { return images.first }
        return viewModel.image(with: currentID)
            ?? images.first(where: { $0.id == currentID })
            ?? images.first
    }

    private var currentRating: Int? {
        currentImage?.rating
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VerticalImageBrowser(
                images: images,
                currentID: $currentID,
                imageProvider: { viewModel.uiImage(for: $0) },
                onSingleTap: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showChrome.toggle()
                    }
                }
            )
            .ignoresSafeArea()

            if showChrome {
                VStack {
                    topBar
                    Spacer()
                    bottomBar
                }
                .transition(.opacity)
            }
        }
        .statusBarHidden(!showChrome)
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
        .sheet(isPresented: $showMoveSheet) {
            if let currentImage {
                MoveImagesSheet(
                    folders: viewModel.folders,
                    currentFolderID: currentImage.folderID ?? viewModel.firstFolder?.id ?? UUID()
                ) { folderID in
                    viewModel.moveImages([currentImage], to: folderID)
                    showMoveSheet = false
                }
                .presentationDetents([.medium])
            }
        }
        .confirmationDialog("Delete Image?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let currentImage {
                    viewModel.deleteImages([currentImage])
                    dismiss()
                }
            }
        }
        .onAppear {
            OrientationLock.beginFullscreenAllowingLandscape()
        }
        .onDisappear {
            OrientationLock.endFullscreen()
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
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

            Spacer(minLength: 8)

            StarRatingControl(
                rating: currentRating,
                starSize: 20,
                spacing: 4,
                hitPadding: 10,
                filledColor: .yellow,
                emptyColor: .white.opacity(0.55)
            ) { newRating in
                guard let currentImage else { return }
                viewModel.setRating(for: currentImage.id, rating: newRating)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial.opacity(0.4), in: Capsule())
            .contentShape(Capsule())

            Spacer(minLength: 8)

            Menu {
                Button("Share", systemImage: "square.and.arrow.up") {
                    shareCurrent()
                }
                Button("Save to Photos", systemImage: "square.and.arrow.down") {
                    Task {
                        if let currentImage {
                            await viewModel.saveToPhotos(currentImage)
                        }
                    }
                }
                Button("Move to Album", systemImage: "folder") {
                    showMoveSheet = true
                }
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive) {
                    showDeleteConfirm = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: ChromeMetrics.iconSize, weight: ChromeMetrics.iconWeight))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .frame(width: ChromeMetrics.hitSize, height: ChromeMetrics.hitSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More")
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        Group {
            if let currentID,
               let index = images.firstIndex(where: { $0.id == currentID }) {
                Text("\(index + 1) / \(images.count)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 20)
            }
        }
    }

    private func shareCurrent() {
        guard let currentImage, let uiImage = viewModel.uiImage(for: currentImage) else { return }
        sharePayload = SharePayload(items: [uiImage])
    }
}
