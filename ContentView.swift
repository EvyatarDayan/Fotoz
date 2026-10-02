//
//  ContentView.swift
//  Fotoz
//

import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: LibraryViewModel
    var revealFolderItems = true

    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            FoldersListView(
                viewModel: viewModel,
                path: $path,
                revealItems: revealFolderItems
            )
            .navigationDestination(for: UUID.self) { folderID in
                if let folder = viewModel.folder(with: folderID) {
                    ImageCollectionView(viewModel: viewModel, folder: folder)
                } else {
                    ContentUnavailableView(
                        "Album Unavailable",
                        systemImage: "folder.badge.questionmark",
                        description: Text("This album no longer exists.")
                    )
                }
            }
        }
        .task {
            syncNavigationForAppReadiness()
        }
        .onChange(of: revealFolderItems) { _, _ in
            syncNavigationForAppReadiness()
        }
        .onChange(of: viewModel.folders.map(\.id)) { _, _ in
            // If the open folder was deleted, return to the folders list.
            if let current = path.last, viewModel.folder(with: current) == nil {
                path = []
            }
        }
        .alert(
            viewModel.errorMessage == ImageLibraryStoreError.duplicateImage.localizedDescription
                ? "Duplication"
                : "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay(alignment: .top) {
            if let infoMessage = viewModel.infoMessage {
                Text(infoMessage)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(1.6))
                            withAnimation {
                                if viewModel.infoMessage == infoMessage {
                                    viewModel.infoMessage = nil
                                }
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.infoMessage)
    }

    private func syncNavigationForAppReadiness() {
        if !viewModel.isDecoySession {
            viewModel.ensureDefaultFolder()
        }
        path = []
        viewModel.allowsAutomaticClipboardImport = false
        viewModel.wantsClipboardImportPrompt = false
    }
}

#Preview {
    ContentView(viewModel: LibraryViewModel())
}
