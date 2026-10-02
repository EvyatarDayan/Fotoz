//
//  OrientationLock.swift
//  Fotoz
//

import UIKit

/// Portrait everywhere except fullscreen image viewing (landscape allowed there).
enum OrientationLock {
    private(set) static var mask: UIInterfaceOrientationMask = .portrait
    private static var fullscreenCount = 0

    @MainActor
    static func beginFullscreenAllowingLandscape() {
        fullscreenCount += 1
        mask = .allButUpsideDown
    }

    @MainActor
    static func endFullscreen() {
        fullscreenCount = max(fullscreenCount - 1, 0)
        guard fullscreenCount == 0 else { return }
        mask = .portrait
        requestPortrait()
    }

    @MainActor
    private static func requestPortrait() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else { return }

        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        scene.windows.forEach { window in
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

final class FotozAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}
