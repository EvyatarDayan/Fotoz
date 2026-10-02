//
//  AppChrome.swift
//  Fotoz
//

import SwiftUI

/// Shared metrics for top-bar icons (Home, album, Settings, etc.).
enum ChromeMetrics {
    static let iconSize: CGFloat = 20
    static let iconWeight: Font.Weight = .semibold
    static let hitSize: CGFloat = 44
    static let horizontalPadding: CGFloat = 12
}

/// Plain top-bar icon (no capsule / circle background) — same size everywhere.
struct ChromeIconButton: View {
    let systemName: String
    var size: CGFloat = ChromeMetrics.iconSize
    var weight: Font.Weight = ChromeMetrics.iconWeight
    var foreground: Color = .primary
    var accessibilityLabel: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(foreground)
                .frame(width: ChromeMetrics.hitSize, height: ChromeMetrics.hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? systemName)
    }
}

/// Custom nav header matching the album/folder top bar (plain chevron + centered title).
struct ChromeNavHeader<Trailing: View>: View {
    let title: String
    var onBack: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.dismiss) private var dismiss

    /// Equal leading/trailing slots keep the title centered.
    private let sideSlotWidth: CGFloat = 64

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                ChromeIconButton(systemName: "chevron.left", accessibilityLabel: "Back") {
                    if let onBack {
                        onBack()
                    } else {
                        dismiss()
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: sideSlotWidth, height: ChromeMetrics.hitSize, alignment: .leading)

            Text(title)
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                trailing()
            }
            .frame(width: sideSlotWidth, height: ChromeMetrics.hitSize, alignment: .trailing)
        }
        .frame(height: ChromeMetrics.hitSize)
        .padding(.horizontal, ChromeMetrics.horizontalPadding)
        .padding(.bottom, 6)
    }
}

extension ChromeNavHeader where Trailing == EmptyView {
    init(title: String, onBack: (() -> Void)? = nil) {
        self.title = title
        self.onBack = onBack
        self.trailing = { EmptyView() }
    }
}
