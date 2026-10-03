//
//  WelcomeView.swift
//  Fotoz
//

import SwiftUI

struct WelcomeView: View {
    /// `true` unlocks the real library; `false` opens the persistent decoy library.
    var onStart: (_ unlocked: Bool) -> Void

    @AppStorage(AppPasswordSettings.protectionEnabledKey) private var passwordProtectionEnabled = false

    @Environment(\.colorScheme) private var colorScheme
    @State private var showCopy = true
    @State private var showLogo = true
    @State private var isStarting = false
    @State private var password = ""
    @State private var showPasswordField = false
    @FocusState private var passwordFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(colorScheme == .dark ? "fotoz_dark" : "fotoz_light")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .opacity(showLogo ? 1 : 0)
                .scaleEffect(showLogo ? 1 : 0.65)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard passwordProtectionEnabled, !isStarting else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPasswordField = true
                    }
                    passwordFocused = true
                }
                .accessibilityLabel(
                    passwordProtectionEnabled ? "Show password field" : "Fotoz"
                )

            VStack(spacing: 16) {
                SplitTitleView("Welcome to Fotoz", splitIndex: 8, fontSize: 28)
                    .frame(maxWidth: .infinity)

                Text("The best image viewer for iOS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                if passwordProtectionEnabled, showPasswordField {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($passwordFocused)
                        .onSubmit(start)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button(action: start) {
                    Text("Get Started")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .background(Color.appRed)
                .clipShape(Capsule())
                .disabled(isStarting)
            }
            .opacity(showCopy ? 1 : 0)
            .scaleEffect(showCopy ? 1 : 0.65)
            .allowsHitTesting(showCopy)

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            (colorScheme == .dark ? Color.black : Color(.systemGroupedBackground))
                .ignoresSafeArea()
        }
    }

    private func start() {
        guard !isStarting else { return }
        isStarting = true

        let unlocked = AppPasswordSettings.validates(password)

        withAnimation(.easeInOut(duration: 0.6)) {
            showCopy = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeInOut(duration: 0.6)) {
                showLogo = false
            }
            try? await Task.sleep(for: .milliseconds(600))
            try? await Task.sleep(for: .milliseconds(500))
            onStart(unlocked)
        }
    }
}

#Preview {
    WelcomeView(onStart: { _ in })
}
