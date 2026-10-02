//
//  SettingsView.swift
//  Fotoz
//

import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @State private var showResetDialog = false
    @State private var resetConfirmationText = ""

    var body: some View {
        VStack(spacing: 0) {
            ChromeNavHeader(title: "Settings")

            List {
                Section {
                    Toggle(isOn: $darkModeEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.blue, in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Dark Mode")
                                Text("Enable dark mode")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(.green)
                    .padding(.vertical, 4)
                } header: {
                    Text("Preferences")
                }

                Section {
                    NavigationLink {
                        LibraryStatisticsView(viewModel: viewModel)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.orange, in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Statistics")
                                Text("Library size and activity")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Library")
                }

                Section {
                    NavigationLink {
                        DeletedItemsView(viewModel: viewModel)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.gray, in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Deleted Items")
                                Text(
                                    viewModel.deletedImages.isEmpty
                                        ? "Kept for 7 days"
                                        : "\(viewModel.deletedImages.count) item\(viewModel.deletedImages.count == 1 ? "" : "s")"
                                )
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Deleted Items")
                }

                Section {
                    Button {
                        resetConfirmationText = ""
                        showResetDialog = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.appRed, in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset App")
                                    .foregroundStyle(Color.appRed)
                                Text("Reset app and delete all")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Danger Zone")
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.top, 0, for: .scrollContent)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.refreshDeletedImages()
        }
        .overlay {
            if showResetDialog {
                ResetAppDialog(
                    confirmationText: $resetConfirmationText,
                    onCancel: {
                        showResetDialog = false
                        resetConfirmationText = ""
                    },
                    onConfirm: {
                        showResetDialog = false
                        resetConfirmationText = ""
                        viewModel.resetApp()
                        dismiss()
                    }
                )
                .ignoresSafeArea()
                .zIndex(1)
            }
        }
    }
}
