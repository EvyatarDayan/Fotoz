//
//  SettingsView.swift
//  Fotoz
//

import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage(AppPasswordSettings.protectionEnabledKey) private var passwordProtectionEnabled = false

    @State private var showResetDialog = false
    @State private var resetConfirmationText = ""
    @State private var showSetPasswordDialog = false
    @State private var passwordDraft = ""
    @State private var confirmPasswordDraft = ""
    @State private var passwordError: String?
    @State private var isChangingPassword = false

    var body: some View {
        VStack(spacing: 0) {
            ChromeNavHeader(title: "Settings")

            List {
                Section {
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

                        Spacer(minLength: 8)

                        Toggle("", isOn: $darkModeEnabled)
                            .labelsHidden()
                            .tint(.green)
                            .scaleEffect(0.78)
                            .frame(width: 40, height: 24)
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.indigo, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Password Protection")
                            Text(
                                passwordProtectionEnabled
                                    ? "Required on welcome screen"
                                    : "Off — welcome opens freely"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Toggle("", isOn: passwordProtectionBinding)
                            .labelsHidden()
                            .tint(.green)
                            .scaleEffect(0.78)
                            .frame(width: 40, height: 24)
                            .disabled(viewModel.isDecoySession)
                    }
                    .padding(.vertical, 4)
                    .disabled(viewModel.isDecoySession)

                    if passwordProtectionEnabled {
                        Button {
                            isChangingPassword = true
                            passwordDraft = ""
                            confirmPasswordDraft = ""
                            passwordError = nil
                            showSetPasswordDialog = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Color.teal, in: Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Change Password")
                                    Text("Update the welcome password")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isDecoySession)
                    }

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
                    .disabled(viewModel.isDecoySession)
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
                        passwordProtectionEnabled = false
                        dismiss()
                    }
                )
                .ignoresSafeArea()
                .zIndex(1)
            }

            if showSetPasswordDialog {
                SetPasswordDialog(
                    title: isChangingPassword ? "Change Password" : "Set Password",
                    password: $passwordDraft,
                    confirmPassword: $confirmPasswordDraft,
                    errorMessage: passwordError,
                    onCancel: {
                        showSetPasswordDialog = false
                        passwordDraft = ""
                        confirmPasswordDraft = ""
                        passwordError = nil
                        if !isChangingPassword {
                            passwordProtectionEnabled = false
                        }
                        isChangingPassword = false
                    },
                    onConfirm: {
                        savePasswordFromDialog()
                    }
                )
                .ignoresSafeArea()
                .zIndex(2)
            }
        }
    }

    private var passwordProtectionBinding: Binding<Bool> {
        Binding(
            get: { passwordProtectionEnabled },
            set: { newValue in
                if newValue {
                    if AppPasswordSettings.storedPassword.isEmpty {
                        isChangingPassword = false
                        passwordDraft = ""
                        confirmPasswordDraft = ""
                        passwordError = nil
                        passwordProtectionEnabled = true
                        showSetPasswordDialog = true
                    } else {
                        passwordProtectionEnabled = true
                    }
                } else {
                    AppPasswordSettings.setProtectionEnabled(false)
                    passwordProtectionEnabled = false
                }
            }
        )
    }

    private func savePasswordFromDialog() {
        let trimmed = passwordDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else {
            passwordError = "Use at least 4 characters."
            return
        }
        guard passwordDraft == confirmPasswordDraft else {
            passwordError = "Passwords don’t match."
            return
        }

        AppPasswordSettings.setPassword(passwordDraft)
        AppPasswordSettings.setProtectionEnabled(true)
        passwordProtectionEnabled = true
        showSetPasswordDialog = false
        passwordDraft = ""
        confirmPasswordDraft = ""
        passwordError = nil
        isChangingPassword = false
    }
}
