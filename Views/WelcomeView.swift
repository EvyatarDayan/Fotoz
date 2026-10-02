//
//  WelcomeView.swift
//  Fotoz
//

import SwiftUI

struct WelcomeView: View {
    var onStart: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showCopy = true
    @State private var showLogo = true
    @State private var isStarting = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(colorScheme == .dark ? "fotoz_dark" : "fotoz_light")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .opacity(showLogo ? 1 : 0)
                .scaleEffect(showLogo ? 1 : 0.65)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                SplitTitleView("Welcome to Fotoz", splitIndex: 8, fontSize: 28)
                    .frame(maxWidth: .infinity)

                Text("The best image viewer for iOS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

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
            onStart()
        }
    }
}

#Preview {
    WelcomeView(onStart: {})
}
