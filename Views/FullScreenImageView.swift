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
    @State private var dragOffset: CGFloat = 0
    @State private var isClosing = false

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
        .animation(.easeOut(duration: 0.2), value: showChrome)
        // Slide the whole viewer away so the album underneath is visible.
        .offset(x: dragOffset)
        .overlay {
            LeftEdgeBackSwipe(
                onChanged: { translation in
                    guard !isClosing else { return }
                    dragOffset = max(0, translation)
                },
                onEnded: { shouldDismiss in
                    if shouldDismiss {
                        requestClose()
                    } else {
                        withAnimation(.easeOut(duration: 0.22)) {
                            dragOffset = 0
                        }
                    }
                }
            )
            .ignoresSafeArea()
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
                    requestClose()
                }
            }
        }
        // Let the album show through while swiping back (not a blank sheet).
        .presentationBackground(.clear)
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
                requestClose()
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

    private func requestClose() {
        guard !isClosing else { return }
        closeSlidingRight()
    }

    private func closeSlidingRight() {
        guard !isClosing else { return }
        isClosing = true
        let width = max(UIScreen.main.bounds.width, dragOffset + 1)
        withAnimation(.easeOut(duration: 0.26)) {
            dragOffset = width
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            // Avoid the default fullScreenCover slide-down after we've already exited right.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dismiss()
            }
        }
    }

    private func shareCurrent() {
        guard let currentImage, let uiImage = viewModel.uiImage(for: currentImage) else { return }
        sharePayload = SharePayload(items: [uiImage])
    }
}

// MARK: - Left-edge swipe back (Veedeo-style)

private struct LeftEdgeBackSwipe: UIViewRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    func makeUIView(context: Context) -> LeftEdgeHitView {
        let view = LeftEdgeHitView()
        view.backgroundColor = .clear
        view.isOpaque = false

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        context.coordinator.pan = pan
        return view
    }

    func updateUIView(_ uiView: LeftEdgeHitView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded: (Bool) -> Void
        weak var pan: UIPanGestureRecognizer?

        init(onChanged: @escaping (CGFloat) -> Void, onEnded: @escaping (Bool) -> Void) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view)
            let velocity = recognizer.velocity(in: recognizer.view)

            switch recognizer.state {
            case .changed:
                onChanged(translation.x)
            case .ended:
                onEnded(translation.x > 70 || velocity.x > 650)
            case .cancelled, .failed:
                onEnded(false)
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan else { return false }
            let location = pan.location(in: pan.view)
            let translation = pan.translation(in: pan.view)
            let velocity = pan.velocity(in: pan.view)
            let isFromLeftEdge = location.x <= 28
            let isHorizontal = abs(velocity.x) > abs(velocity.y) || abs(translation.x) > abs(translation.y)
            let isSwipingRight = translation.x >= 0 || velocity.x > 0
            return isFromLeftEdge && isHorizontal && isSwipingRight
        }
    }
}

private final class LeftEdgeHitView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Leave the top chrome alone so Back / stars / menu stay easy to tap.
        let topChromeExclusion: CGFloat = 72
        guard point.y > topChromeExclusion else { return false }
        return point.x <= 28
    }
}
