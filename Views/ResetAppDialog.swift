//
//  ResetAppDialog.swift
//  Fotoz
//

import SwiftUI

struct ResetAppDialog: View {
    @Binding var confirmationText: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isPresented = false

    private var canReset: Bool {
        confirmationText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("reset app") == .orderedSame
    }

    var body: some View {
        ZStack {
            Color.black.opacity(isPresented ? 0.28 : 0)
                .ignoresSafeArea()
                .onTapGesture(perform: dismissAnimated)

            VStack(alignment: .leading, spacing: 14) {
                Text("Reset App")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(
                    #"Are you sure? All images will be deleted permanently. This action cannot be undone! Type "reset app" to complete this action."#
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                TextField("reset app", text: $confirmationText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.none)

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
                        Text("Reset")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appRed, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canReset)
                    .opacity(canReset ? 1 : 0.45)
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
        guard canReset else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onConfirm()
        }
    }
}
