//
//  FotozApp.swift
//  Fotoz
//

import SwiftUI

@main
struct FotozApp: App {
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @State private var showWelcome = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(revealFolderItems: !showWelcome)
                    .allowsHitTesting(!showWelcome)

                if showWelcome {
                    WelcomeView {
                        showWelcome = false
                    }
                    .ignoresSafeArea()
                    .zIndex(1)
                }
            }
            .preferredColorScheme(darkModeEnabled ? .dark : .light)
        }
    }
}
