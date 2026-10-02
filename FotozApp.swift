//
//  FotozApp.swift
//  Fotoz
//

import SwiftUI

@main
struct FotozApp: App {
    @UIApplicationDelegateAdaptor(FotozAppDelegate.self) private var appDelegate
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @State private var viewModel = LibraryViewModel()
    @State private var showWelcome = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(
                    viewModel: viewModel,
                    revealFolderItems: !showWelcome
                )
                .allowsHitTesting(!showWelcome)

                if showWelcome {
                    WelcomeView { unlocked in
                        if !unlocked {
                            viewModel.enterDecoySession()
                        }
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
