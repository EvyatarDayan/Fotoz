//
//  FolderNameDialog.swift
//  Fotoz
//

import SwiftUI

struct FolderNameDialog: View {
    let title: String
    let confirmTitle: String
    @Binding var name: String
    var showNameExistsError = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isPresented = false

    private var canConfirm: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count
            >= LibraryViewModel.minFolderNameLength
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

                TextField("Album name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.none)
                    .onChange(of: name) { _, value in
                        if value.count > LibraryViewModel.maxFolderNameLength {
                            name = String(value.prefix(LibraryViewModel.maxFolderNameLength))
                        }
                    }

                Text("Name exist, pick another")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.appRed)
                    .opacity(showNameExistsError ? 1 : 0)
                    .accessibilityHidden(!showNameExistsError)
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
                        Text(confirmTitle)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canConfirm)
                    .opacity(canConfirm ? 1 : 0.45)
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
        guard canConfirm else { return }
        // Keep the dialog up if the parent reports a name conflict.
        onConfirm()
    }
}
