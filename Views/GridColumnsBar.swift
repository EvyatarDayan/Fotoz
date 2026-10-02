//
//  GridColumnsBar.swift
//  Fotoz
//

import SwiftUI

struct GridColumnsBar: View {
    @Binding var value: Double

    @Environment(\.colorScheme) private var colorScheme
    private let range: ClosedRange<Double> = 3...6

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let thumbSize: CGFloat = 16
            let trackHeight: CGFloat = 4
            let travel = max(width - thumbSize, 1)
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbX = progress * travel

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.28))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.appRed)
                    .frame(width: max(thumbX + thumbSize * 0.5, trackHeight), height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 2.5, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: thumbX)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let x = min(max(drag.location.x - thumbSize * 0.5, 0), travel)
                        let next = range.lowerBound + (range.upperBound - range.lowerBound) * Double(x / travel)
                        value = min(max(next, range.lowerBound), range.upperBound)
                    }
            )
        }
        .frame(width: 148, height: 28)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.72 : 0.55))
        )
        .accessibilityLabel("Images per row")
        .accessibilityValue("\(Int(value.rounded()))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(value + 0.2, range.upperBound)
            case .decrement:
                value = max(value - 0.2, range.lowerBound)
            @unknown default:
                break
            }
        }
    }
}
