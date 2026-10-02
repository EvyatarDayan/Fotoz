//
//  FoldersListView.swift
//  Fotoz
//

import SwiftUI
import UIKit

private enum LibraryPane: String, CaseIterable, Identifiable {
    case home
    case albums

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .albums: "Albums"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .albums: "folder.fill"
        }
    }
}

struct FoldersListView: View {
    @Bindable var viewModel: LibraryViewModel
    @Binding var path: [UUID]
    var revealItems = true

    @AppStorage("gridColumnsValue") private var columnsValue = 3.0

    @State private var selectedPane: LibraryPane = .home
    @State private var minRating: Int?
    @State private var viewerImageID: LibraryImage.ID?
    @State private var selectedIDs: Set<LibraryImage.ID> = []
    @State private var sharePayload: SharePayload?
    @State private var showMoveSheet = false
    @State private var imagesPendingMove: [LibraryImage] = []

    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var showNewFolderNameExistsError = false
    @State private var folderToRename: Folder?
    @State private var renameFolderText = ""
    @State private var showRenameNameExistsError = false
    @State private var folderToDelete: Folder?
    @State private var showSettings = false

    @State private var homeEntrance = GridEntranceController()

    private let albumColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    private let contentSidePadding: CGFloat = 16

    private var resolvedColumnsPerRow: Int {
        min(max(Int(columnsValue.rounded()), 3), 6)
    }

    private var recentImages: [LibraryImage] {
        viewModel.recentImages(limit: 20)
    }

    private var homeImages: [LibraryImage] {
        recentImages.filter { $0.matches(minRating: minRating) }
    }

    private var homeBackground: Color {
        Color(.systemGroupedBackground)
    }

    var body: some View {
        VStack(spacing: 0) {
            libraryHeader

            paneToggle
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 14)

            switch selectedPane {
            case .home:
                homeContent
            case .albums:
                albumsContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .overlay {
            if showNewFolder {
                FolderNameDialog(
                    title: "New Album",
                    confirmTitle: "Create",
                    name: $newFolderName,
                    showNameExistsError: showNewFolderNameExistsError,
                    onCancel: {
                        showNewFolder = false
                        showNewFolderNameExistsError = false
                    },
                    onConfirm: {
                        if let folder = viewModel.createFolder(named: newFolderName) {
                            showNewFolder = false
                            showNewFolderNameExistsError = false
                            selectedPane = .albums
                            path = [folder.id]
                        } else {
                            showNewFolderNameExistsError = viewModel.folderNameExists(newFolderName)
                        }
                    }
                )
            } else if folderToRename != nil {
                FolderNameDialog(
                    title: "Rename Album",
                    confirmTitle: "Save",
                    name: $renameFolderText,
                    showNameExistsError: showRenameNameExistsError,
                    onCancel: {
                        folderToRename = nil
                        showRenameNameExistsError = false
                    },
                    onConfirm: {
                        guard let folderToRename else { return }
                        if viewModel.renameFolder(folderToRename, to: renameFolderText) {
                            self.folderToRename = nil
                            showRenameNameExistsError = false
                        } else {
                            showRenameNameExistsError = viewModel.folderNameExists(
                                renameFolderText,
                                excludingFolderID: folderToRename.id
                            )
                        }
                    }
                )
            } else if folderToDelete != nil {
                deleteFolderDialog
            }
        }
        .onAppear {
            if columnsValue < 3 || columnsValue > 6 {
                columnsValue = 3
            }
            playHomeEntranceIfNeeded()
        }
        .onChange(of: revealItems) { _, shouldReveal in
            if shouldReveal {
                playHomeEntranceIfNeeded()
            }
        }
        .onChange(of: selectedPane) { _, pane in
            if pane == .home {
                playHomeEntranceIfNeeded()
            }
        }
        .onChange(of: homeImages.map(\.id)) { _, ids in
            homeEntrance.playIfNeeded(ids: ids)
        }
        .onChange(of: newFolderName) { _, _ in
            showNewFolderNameExistsError = false
        }
        .onChange(of: renameFolderText) { _, _ in
            showRenameNameExistsError = false
        }
        .fullScreenCover(item: viewerBinding) { image in
            FullScreenImageView(
                viewModel: viewModel,
                images: homeImages,
                startID: image.id
            )
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveImagesSheet(
                folders: viewModel.folders,
                currentFolderID: imagesPendingMove.first?.folderID
                    ?? viewModel.firstFolder?.id
                    ?? UUID()
            ) { destination in
                viewModel.moveImages(imagesPendingMove, to: destination)
                imagesPendingMove = []
                showMoveSheet = false
            }
            .presentationDetents([.medium])
        }
        .overlay(alignment: .bottom) {
            if selectedPane == .home, !homeImages.isEmpty {
                GridColumnsBar(value: $columnsValue)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Header & toggle

    private var libraryHeader: some View {
        HStack {
            ChromeIconButton(systemName: "gearshape", accessibilityLabel: "Settings") {
                showSettings = true
            }

            Spacer(minLength: 0)

            FotozWordmark()

            Spacer(minLength: 0)

            addButton
        }
        .padding(.horizontal, ChromeMetrics.horizontalPadding)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var addButton: some View {
        if selectedPane == .albums {
            ChromeIconButton(systemName: "plus", accessibilityLabel: "New album") {
                newFolderName = ""
                showNewFolderNameExistsError = false
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    showNewFolder = true
                }
            }
        } else {
            Color.clear
                .frame(width: ChromeMetrics.hitSize, height: ChromeMetrics.hitSize)
                .accessibilityHidden(true)
        }
    }

    private var paneToggle: some View {
        let selectedColor = Color.appRed

        return HStack(spacing: 0) {
            ForEach(LibraryPane.allCases) { pane in
                let isSelected = selectedPane == pane
                Button {
                    selectedPane = pane
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: pane.icon)
                            .font(.subheadline.weight(.semibold))
                        Text(pane.title)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(isSelected ? selectedColor : Color.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .background(alignment: .leading) {
            GeometryReader { geometry in
                let width = geometry.size.width / CGFloat(LibraryPane.allCases.count)
                let index = CGFloat(LibraryPane.allCases.firstIndex(of: selectedPane) ?? 0)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selectedColor.opacity(0.12))
                    .frame(width: width)
                    .offset(x: width * index)
            }
        }
        .padding(3)
        .frame(height: 48)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: selectedPane)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Switch between Home and Albums")
    }

    // MARK: - Home

    @ViewBuilder
    private var homeContent: some View {
        VStack(spacing: 0) {
            if !recentImages.isEmpty {
                RatingFilterBar(minRating: $minRating)
                    .padding(.top, 0)
                    .padding(.bottom, 10)

                Divider()
                    .padding(.bottom, 10)
            }

            Group {
                if recentImages.isEmpty {
                    ContentUnavailableView {
                        Label("No photos yet", systemImage: "photo.on.rectangle")
                    } description: {
                        Text("Tap + to add photos from Photos or Files, or paste from the clipboard.")
                    }
                } else if homeImages.isEmpty {
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
                        let visibleIDs = homeEntrance.visibleIDs
                        let entranceDone = homeEntrance.didFinish
                        ImageGridView(
                            viewModel: viewModel,
                            images: homeImages,
                            emptyTitle: "No photos yet",
                            emptySystemImage: "photo.on.rectangle",
                            columnsPerRow: resolvedColumnsPerRow,
                            pageBackground: homeBackground,
                            isItemVisible: { entranceDone || visibleIDs.contains($0.id) },
                            selectedIDs: $selectedIDs,
                            isSelecting: false,
                            onOpen: { viewerImageID = $0.id },
                            onShare: { share(image: $0) },
                            onMove: { presentMove(for: [$0]) }
                        )
                        .animation(
                            .spring(response: 0.52, dampingFraction: 0.86),
                            value: resolvedColumnsPerRow
                        )
                        .padding(.bottom, 72)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, contentSidePadding)
    }

    // MARK: - Albums

    @ViewBuilder
    private var albumsContent: some View {
        Group {
            if viewModel.folders.isEmpty {
                ContentUnavailableView {
                    Label("No albums yet", systemImage: "folder")
                } description: {
                    Text("Tap + to create a new album")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: albumColumns, spacing: 14) {
                        ForEach(viewModel.folders) { folder in
                            NavigationLink(value: folder.id) {
                                FolderTile(
                                    folder: folder,
                                    imageCount: viewModel.imageCount(in: folder.id),
                                    coverImages: viewModel.coverImages(in: folder.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    showRenameNameExistsError = false
                                    folderToRename = folder
                                    renameFolderText = folder.name
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    folderToDelete = folder
                                } label: {
                                    Label("Delete Album", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Dialogs & helpers

    private var deleteFolderDialog: some View {
        let imageCount = folderToDelete.map { viewModel.imageCount(in: $0.id) } ?? 0
        let imageWord = imageCount == 1 ? "image" : "images"

        return ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture {
                    folderToDelete = nil
                }

            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Are you sure?")
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text("This will delete the album and its content (\(imageCount) \(imageWord)).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    Button("Cancel") {
                        folderToDelete = nil
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())

                    Button("Yes") {
                        if let folderToDelete {
                            let deletedID = folderToDelete.id
                            viewModel.deleteFolder(folderToDelete, deleteImages: true)
                            if path.contains(deletedID) {
                                path = []
                            }
                        }
                        folderToDelete = nil
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(Color.appRed)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }
                .font(.body.weight(.semibold))
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    private var viewerBinding: Binding<LibraryImage?> {
        Binding(
            get: {
                guard let viewerImageID else { return nil }
                return homeImages.first(where: { $0.id == viewerImageID })
                    ?? viewModel.image(with: viewerImageID)
            },
            set: { newValue in
                viewerImageID = newValue?.id
            }
        )
    }

    private func share(image: LibraryImage) {
        guard let uiImage = viewModel.uiImage(for: image) else { return }
        sharePayload = SharePayload(items: [uiImage])
    }

    private func presentMove(for images: [LibraryImage]) {
        guard !images.isEmpty else { return }
        imagesPendingMove = images
        showMoveSheet = true
    }

    private func playHomeEntranceIfNeeded() {
        guard selectedPane == .home, revealItems else { return }
        homeEntrance.playIfNeeded(ids: homeImages.map(\.id))
    }
}

struct FolderTile: View {
    let folder: Folder
    let imageCount: Int
    let coverImages: [UIImage]

    @Environment(\.colorScheme) private var colorScheme

    private let dividerWidth: CGFloat = 1

    private var dividerColor: Color {
        colorScheme == .dark ? Color(white: 0.12) : Color.black
    }

    private var displayName: String {
        let name = folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.count <= LibraryViewModel.maxFolderNameLength {
            return name
        }
        return String(name.prefix(LibraryViewModel.maxFolderNameLength))
    }

    private var isEmptyFolder: Bool {
        coverImages.isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            folderPreview

            // Full-width bottom scrim — clearer than a floating center chip.
            LinearGradient(
                colors: [
                    .black.opacity(0),
                    .black.opacity(0.55),
                    .black.opacity(0.82),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 88)
            .frame(maxWidth: .infinity, alignment: .bottom)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)

                Text(imageCount == 1 ? "1 photo" : "\(imageCount) photos")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(dividerColor, lineWidth: dividerWidth)
        }
        .compositingGroup()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(displayName), \(imageCount == 1 ? "1 photo" : "\(imageCount) photos")")
    }

    @ViewBuilder
    private var folderPreview: some View {
        let covers = Array(coverImages.prefix(4))

        GeometryReader { geo in
            Group {
                if covers.count >= 4 {
                    let side = (min(geo.size.width, geo.size.height) - dividerWidth) / 2

                    VStack(spacing: dividerWidth) {
                        HStack(spacing: dividerWidth) {
                            filledSquare(covers[0], side: side)
                            filledSquare(covers[1], side: side)
                        }
                        HStack(spacing: dividerWidth) {
                            filledSquare(covers[2], side: side)
                            filledSquare(covers[3], side: side)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                } else if let cover = covers.first {
                    filledSquare(cover, side: min(geo.size.width, geo.size.height))
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    Rectangle().fill(Color.black)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(isEmptyFolder ? Color.black : dividerColor)
        }
    }

    private func filledSquare(_ image: UIImage, side: CGFloat) -> some View {
        Color.clear
            .frame(width: side, height: side)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }
}
