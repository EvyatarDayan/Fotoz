//
//  StarRatingControl.swift
//  Fotoz
//

import SwiftUI
import UIKit

struct StarRatingControl: View {
    let rating: Int?
    var maxRating: Int = 5
    var starSize: CGFloat = 18
    var spacing: CGFloat = 6
    /// Extra invisible padding around each star to make taps easier.
    var hitPadding: CGFloat = 0
    var filledColor: Color = .yellow
    var emptyColor: Color = .white.opacity(0.55)
    var allowsClearing: Bool = true
    let onSelect: (Int?) -> Void

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { value in
                Button {
                    if allowsClearing, rating == value {
                        onSelect(nil)
                    } else {
                        onSelect(value)
                    }
                } label: {
                    Image(systemName: starSymbol(for: value))
                        .font(.system(size: starSize, weight: .semibold))
                        .foregroundStyle(value <= (rating ?? 0) ? filledColor : emptyColor)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(
                            width: max(starSize + hitPadding * 2, 28),
                            height: max(starSize + hitPadding * 2, 36)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(value) star\(value == 1 ? "" : "s")")
                .accessibilityAddTraits(value == rating ? .isSelected : [])
            }
        }
    }

    private func starSymbol(for value: Int) -> String {
        value <= (rating ?? 0) ? "star.fill" : "star"
    }
}

struct RatingFilterBar: View {
    @Binding var minRating: Int?

    var body: some View {
        HStack(spacing: 12) {
            Text("Filter by rating")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            StarRatingControl(
                rating: minRating,
                starSize: 18,
                spacing: 6,
                filledColor: .yellow,
                emptyColor: Color.secondary.opacity(0.45)
            ) { newRating in
                minRating = newRating
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            Button {
                minRating = nil
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(minRating == nil)
            .opacity(minRating == nil ? 0.35 : 1)
            .accessibilityLabel("Clear rating filter")
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter by rating")
    }
}

struct RatingFilterEmptyState: View {
    let rating: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(value <= rating ? Color.yellow : Color.secondary.opacity(0.45))
                }
            }
            .accessibilityLabel("\(rating) star\(rating == 1 ? "" : "s")")

            Text("There are no photos rated with \(rating) star\(rating == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
