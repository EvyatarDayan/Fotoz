//
//  SetPasswordDialog.swift
//  Fotoz
//

import SwiftUI

struct SetPasswordDialog: View {
    let title: String
    @Binding var password: String
    @Binding var confirmPassword: String
    var errorMessage: String?
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isPresented = false

    private var canSave: Bool {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 4 && password == confirmPassword
    }

    var body: some View {
        ZStack {
            Color.black.opacity(isPresented ? 0.28 : 0)
                .ignoresSafeArea()
                .onTapGesture(perform: dismissAnimated)

            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("Choose a password with at least 4 characters.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.newPassword)

                SecureField("Confirm password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.newPassword)

                Text(errorMessage ?? " ")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.appRed)
                    .opacity(errorMessage == nil ? 0 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 18)

                HStack(spacing: 10) {
                    Button(action: dismissAnimated) {
                        Text("Cancel")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: confirmAnimated) {
                        Text("Save")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appRed, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)
                }
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .scaleEffect(isPresented ? 1 : 0.82)
            .opacity(isPresented ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78, blendDuration: 0.15)) {
                isPresented = true
            }
        }
    }

    private func dismissAnimated() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onCancel()
        }
    }

    private func confirmAnimated() {
        guard canSave else { return }
        onConfirm()
    }
}
