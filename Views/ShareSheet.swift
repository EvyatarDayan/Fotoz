//
//  ShareSheet.swift
//  Fotoz
//

import SwiftUI
import UIKit

/// Identifiable wrapper so SwiftUI presents the share sheet only after items are ready
/// (avoids the empty first-open UIActivityViewController bug).
struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
