//
//  FullScreenImageView.swift
//  Fotoz
//

import SwiftUI
import UIKit

struct FullScreenImageView: View {
    @Bindable var viewModel: LibraryViewModel
    let images: [LibraryImage]
    @State private var currentID: LibraryImage.ID
    @Environment(\.dismiss) private var dismiss

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
        viewModel.image(with: currentID)
            ?? images.first(where: { $0.id == currentID })
            ?? images.first
    }

    private var currentRating: Int? {
        currentImage?.rating
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentID) {
                ForEach(images) { image in
                    ZoomableImagePage(
                        uiImage: viewModel.uiImage(for: image),
                        isActive: image.id == currentID,
                        onSingleTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showChrome.toggle()
                            }
                        }
                    )
                    .tag(image.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
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
            if let index = images.firstIndex(where: { $0.id == currentID }) {
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

private struct ZoomableImagePage: View {
    let uiImage: UIImage?
    let isActive: Bool
    let onSingleTap: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private var isZoomed: Bool {
        scale > 1.01
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if isZoomed {
                                    resetTransform()
                                } else {
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                        .onTapGesture(count: 1) {
                            onSingleTap()
                        }
                        .gesture(magnificationGesture)
                        .gesture(isZoomed ? panGesture : nil)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            // When not zoomed, let TabView own horizontal swipes for paging.
            .contentShape(Rectangle())
        }
        .onChange(of: isActive) { _, active in
            if !active {
                resetTransform()
            }
        }
        .onChange(of: uiImage) { _, _ in
            resetTransform()
        }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let next = lastScale * value.magnification
                scale = min(max(next, 1), 5)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        resetTransform()
                    }
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func resetTransform() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
