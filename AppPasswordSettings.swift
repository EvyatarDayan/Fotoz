//
//  AppPasswordSettings.swift
//  Fotoz
//

import Foundation

enum AppPasswordSettings {
    static let protectionEnabledKey = "passwordProtectionEnabled"
    static let passwordKey = "appUnlockPassword"

    static var isProtectionEnabled: Bool {
        UserDefaults.standard.bool(forKey: protectionEnabledKey)
    }

    static var storedPassword: String {
        UserDefaults.standard.string(forKey: passwordKey) ?? ""
    }

    static func setProtectionEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: protectionEnabledKey)
        if !enabled {
            UserDefaults.standard.removeObject(forKey: passwordKey)
        }
    }

    static func setPassword(_ password: String) {
        UserDefaults.standard.set(password, forKey: passwordKey)
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: protectionEnabledKey)
        UserDefaults.standard.removeObject(forKey: passwordKey)
    }

    /// Returns `true` when the entered password unlocks the real library.
    static func validates(_ attempt: String) -> Bool {
        guard isProtectionEnabled else { return true }
        let expected = storedPassword
        guard !expected.isEmpty else { return true }
        return attempt == expected
    }
}
