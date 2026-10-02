//
//  ImageGridView.swift
//  Fotoz
//

import SwiftUI
import UIKit

enum ImageGridMenuStyle {
    case library
    case trash
}

struct ImageGridView: View {
    @Bindable var viewModel: LibraryViewModel
    let images: [LibraryImage]
    let emptyTitle: String
    let emptySystemImage: String
    let columnsPerRow: Int
    var pageBackground: Color = Color(.systemGroupedBackground)
    /// When provided, cells fade/slide in only after their id is included (Veedeo-style entrance).
    var isItemVisible: ((LibraryImage) -> Bool)? = nil
    var resolveUIImage: ((LibraryImage) -> UIImage?)? = nil
    var menuStyle: ImageGridMenuStyle = .library

    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedIDs: Set<LibraryImage.ID>
    let isSelecting: Bool
    let onOpen: (LibraryImage) -> Void
    var onShare: (LibraryImage) -> Void = { _ in }
    var onMove: (LibraryImage) -> Void = { _ in }
    var onRestore: (LibraryImage) -> Void = { _ in }
    var onDeleteForever: (LibraryImage) -> Void = { _ in }

    private let dividerWidth: CGFloat = 1
    /// Matches `RatingFilterBar` corner radius.
    private let gridCornerRadius: CGFloat = 14

    private var dividerColor: Color {
        colorScheme == .dark ? Color(white: 0.12) : Color.black
    }

    private var columnCount: Int {
        max(columnsPerRow, 1)
    }

    var body: some View {
        if images.isEmpty {
            ContentUnavailableView(
                emptyTitle,
                systemImage: emptySystemImage,
                description: Text("Paste from clipboard, or import from Photos or Files.")
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            let outline = PhotoBulkOutline(
                imageCount: images.count,
                columns: columnCount,
                cornerRadius: gridCornerRadius
            )

            // One clip + one inset stroke. Avoid per-cell corner clips (those stacked
            // with the outline and made corners look double-thick).
            SquarePhotoGridLayout(columns: CGFloat(columnCount), spacing: 0) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                    let visible = isItemVisible?(image) ?? true
                    gridCell(for: image)
                        .overlay(alignment: .trailing) {
                            if showsInternalTrailingDivider(at: index) {
                                Rectangle()
                                    .fill(dividerColor)
                                    .frame(width: dividerWidth)
                                    .allowsHitTesting(false)
                                    .opacity(visible ? 1 : 0)
                                    .animation(GridEntrance.animation, value: visible)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if showsInternalBottomDivider(at: index) {
                                Rectangle()
                                    .fill(dividerColor)
                                    .frame(height: dividerWidth)
                                    .allowsHitTesting(false)
                                    .opacity(visible ? 1 : 0)
                                    .animation(GridEntrance.animation, value: visible)
                            }
                        }
                        .scaleEffect(visible ? 1 : GridEntrance.startScale)
                        .opacity(visible ? 1 : 0)
                        .animation(GridEntrance.animation, value: visible)
                        // Keep hit targets inside the laid-out cell (neighbors sit on top in z-order).
                        .clipped()
                        .contentShape(Rectangle())
                }
            }
            .background(pageBackground)
            .clipShape(outline)
            .overlay {
                outline
                    .strokeBorder(dividerColor, lineWidth: dividerWidth)
                    .allowsHitTesting(false)
            }
        }
    }

    private func row(for index: Int) -> Int { index / columnCount }
    private func column(for index: Int) -> Int { index % columnCount }

    private var lastRowIndex: Int { (images.count - 1) / columnCount }

    private func showsInternalTrailingDivider(at index: Int) -> Bool {
        let column = column(for: index)
        guard column < columnCount - 1 else { return false }
        return index + 1 < images.count
    }

    private func showsInternalBottomDivider(at index: Int) -> Bool {
        row(for: index) < lastRowIndex
    }

    @ViewBuilder
    private func gridCell(for image: LibraryImage) -> some View {
        let isSelected = selectedIDs.contains(image.id)

        Button {
            if isSelecting {
                if isSelected {
                    selectedIDs.remove(image.id)
                } else {
                    selectedIDs.insert(image.id)
                }
            } else {
                onOpen(image)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                ThumbnailView(
                    image: image,
                    uiImage: resolveUIImage?(image) ?? viewModel.uiImage(for: image)
                )

                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            isSelected ? Color.white : Color.white.opacity(0.9),
                            isSelected ? Color.appRed : Color.black.opacity(0.35)
                        )
                        .font(.title3)
                        .padding(6)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .contextMenu {
            if !isSelecting {
                switch menuStyle {
                case .library:
                    Button("Share", systemImage: "square.and.arrow.up") {
                        onShare(image)
                    }
                    Button("Save to Photos", systemImage: "square.and.arrow.down") {
                        Task { await viewModel.saveToPhotos(image) }
                    }
                    Button("Move to Album", systemImage: "folder") {
                        onMove(image)
                    }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        viewModel.deleteImages([image])
                    }
                case .trash:
                    Button("Restore", systemImage: "arrow.uturn.backward") {
                        onRestore(image)
                    }
                    Divider()
                    Button("Delete Forever", systemImage: "trash", role: .destructive) {
                        onDeleteForever(image)
                    }
                }
            }
        }
    }
}

/// Outer silhouette of the photo bulk, including stepped incomplete last rows,
/// with continuous rounded corners on the outer extremes.
private struct PhotoBulkOutline: InsettableShape {
    var imageCount: Int
    var columns: Int
    var cornerRadius: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let cols = max(columns, 1)
        let count = max(imageCount, 0)
        guard count > 0, rect.width > 0, rect.height > 0 else { return Path() }

        let cell = rect.width / CGFloat(cols)
        let lastRow = (count - 1) / cols
        let lastRowCount = count - lastRow * cols
        let lastRowWidth = CGFloat(lastRowCount) * cell
        let height = CGFloat(lastRow + 1) * cell

        let bounds = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: height)
            .insetBy(dx: insetAmount, dy: insetAmount)
        guard bounds.width > 0, bounds.height > 0 else { return Path() }

        let radius = min(
            max(cornerRadius - insetAmount, 0),
            min(bounds.width, bounds.height, lastRowWidth - insetAmount * 2) / 2
        )

        if lastRow == 0 || lastRowCount == cols {
            return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: bounds)
        }

        // Stepped outline for an incomplete last row.
        let top = bounds.minY
        let left = bounds.minX
        let right = bounds.maxX
        // Keep the step aligned to the photo grid (account for inset).
        let midY = rect.minY + CGFloat(lastRow) * cell + insetAmount
        let bottom = bounds.maxY
        let stepRight = rect.minX + lastRowWidth - insetAmount

        var path = Path()
        path.move(to: CGPoint(x: left + radius, y: top))
        path.addLine(to: CGPoint(x: right - radius, y: top))
        path.addQuadCurve(
            to: CGPoint(x: right, y: top + radius),
            control: CGPoint(x: right, y: top)
        )
        path.addLine(to: CGPoint(x: right, y: midY))
        path.addLine(to: CGPoint(x: stepRight, y: midY))
        path.addLine(to: CGPoint(x: stepRight, y: bottom - radius))
        path.addQuadCurve(
            to: CGPoint(x: stepRight - radius, y: bottom),
            control: CGPoint(x: stepRight, y: bottom)
        )
        path.addLine(to: CGPoint(x: left + radius, y: bottom))
        path.addQuadCurve(
            to: CGPoint(x: left, y: bottom - radius),
            control: CGPoint(x: left, y: bottom)
        )
        path.addLine(to: CGPoint(x: left, y: top + radius))
        path.addQuadCurve(
            to: CGPoint(x: left + radius, y: top),
            control: CGPoint(x: left, y: top)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> PhotoBulkOutline {
        PhotoBulkOutline(
            imageCount: imageCount,
            columns: columns,
            cornerRadius: cornerRadius,
            insetAmount: insetAmount + amount
        )
    }
}

/// Interpolates cell frames between integer column counts while `columns` animates.
private struct SquarePhotoGridLayout: Layout {
    var columns: CGFloat
    var spacing: CGFloat

    var animatableData: CGFloat {
        get { columns }
        set { columns = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        guard width > 0, !subviews.isEmpty else { return .zero }

        let lower = max(Int(floor(columns)), 1)
        let upper = max(Int(ceil(columns)), 1)
        let progress = interpolationProgress(lower: lower, upper: upper)

        let lowerHeight = height(for: subviews.count, columns: lower, width: width)
        let upperHeight = height(for: subviews.count, columns: upper, width: width)
        let height = lowerHeight + (upperHeight - lowerHeight) * progress
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let lower = max(Int(floor(columns)), 1)
        let upper = max(Int(ceil(columns)), 1)
        let progress = interpolationProgress(lower: lower, upper: upper)

        for (index, subview) in subviews.enumerated() {
            let from = frame(for: index, columns: lower, in: bounds)
            let to = frame(for: index, columns: upper, in: bounds)

            let x = from.minX + (to.minX - from.minX) * progress
            let y = from.minY + (to.minY - from.minY) * progress
            let side = from.width + (to.width - from.width) * progress

            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: side, height: side)
            )
        }
    }

    private func interpolationProgress(lower: Int, upper: Int) -> CGFloat {
        guard upper > lower else { return 0 }
        return min(max(columns - CGFloat(lower), 0), 1)
    }

    private func height(for count: Int, columns: Int, width: CGFloat) -> CGFloat {
        let colCount = max(columns, 1)
        let cell = cellSide(containerWidth: width, columns: colCount)
        let rowCount = Int(ceil(Double(count) / Double(colCount)))
        return CGFloat(rowCount) * cell + CGFloat(max(rowCount - 1, 0)) * spacing
    }

    private func frame(for index: Int, columns: Int, in bounds: CGRect) -> CGRect {
        let colCount = max(columns, 1)
        let cell = cellSide(containerWidth: bounds.width, columns: colCount)
        let column = index % colCount
        let row = index / colCount
        let x = bounds.minX + CGFloat(column) * (cell + spacing)
        let y = bounds.minY + CGFloat(row) * (cell + spacing)
        return CGRect(x: x, y: y, width: cell, height: cell)
    }

    private func cellSide(containerWidth: CGFloat, columns: Int) -> CGFloat {
        let colCount = CGFloat(max(columns, 1))
        return max((containerWidth - spacing * (colCount - 1)) / colCount, 0)
    }
}
