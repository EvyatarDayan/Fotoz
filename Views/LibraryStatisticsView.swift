//
//  LibraryStatisticsView.swift
//  Fotoz
//

import SwiftUI

struct LibraryStatisticsView: View {
    @Bindable var viewModel: LibraryViewModel

    private var stats: LibraryStatistics {
        LibraryStatistics(
            images: viewModel.images,
            albums: viewModel.folders,
            libraryBytes: viewModel.libraryBytesOnDisk,
            trashBytes: viewModel.trashBytesOnDisk
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ChromeNavHeader(title: "Statistics")

            List {
                Section("Library") {
                    statRow(icon: "photo.fill", color: Color.appRed, title: "Photos", value: "\(stats.photoCount)")
                    statRow(icon: "folder.fill", color: .orange, title: "Albums", value: "\(stats.albumCount)")
                    if let average = stats.averagePhotosPerAlbum {
                        statRow(icon: "rectangle.stack.fill", color: .indigo, title: "Avg per Album", value: average)
                    }
                }

                Section("Storage") {
                    statRow(icon: "externaldrive.fill", color: .green, title: "Photos on Disk", value: formatBytes(stats.libraryBytes))
                    statRow(icon: "trash.fill", color: .gray, title: "Deleted Items", value: formatBytes(stats.trashBytes))
                    statRow(icon: "internaldrive.fill", color: .mint, title: "Total Used", value: formatBytes(stats.totalBytes))
                    if let average = stats.averageBytes {
                        statRow(icon: "doc.fill", color: .cyan, title: "Average Size", value: formatBytes(average))
                    }
                }

                Section("Ratings") {
                    statRow(icon: "star.fill", color: .yellow, title: "Rated", value: "\(stats.ratedCount)")
                    statRow(icon: "star", color: .gray, title: "Unrated", value: "\(stats.unratedCount)")
                    statRow(icon: "star.leadinghalf.filled", color: .orange, title: "Average Rating", value: formatAverageRating(stats.averageRating))
                    statRow(icon: "sparkles", color: .yellow, title: "5-Star Photos", value: "\(stats.fiveStarCount)")
                }

                if !stats.sourceCounts.isEmpty {
                    Section("Sources") {
                        ForEach(stats.sourceCounts, id: \.name) { item in
                            statRow(
                                icon: sourceIcon(item.name),
                                color: sourceColor(item.name),
                                title: sourceTitle(item.name),
                                value: "\(item.count)"
                            )
                        }
                    }
                }

                Section("Activity") {
                    statRow(icon: "calendar", color: .blue, title: "Added This Week", value: "\(stats.addedThisWeek)")
                    statRow(icon: "calendar.badge.clock", color: .indigo, title: "Added This Month", value: "\(stats.addedThisMonth)")
                    if let newest = stats.newestAddedAt {
                        statRow(icon: "plus.circle.fill", color: .green, title: "Latest Import", value: formatDate(newest))
                    }
                    if let oldest = stats.oldestAddedAt {
                        statRow(icon: "clock.arrow.circlepath", color: .secondary, title: "First Import", value: formatDate(oldest))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func statRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: Circle())

            Text(title)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formatAverageRating(_ rating: Double?) -> String {
        guard let rating else { return "—" }
        return String(format: "%.1f", rating)
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func sourceTitle(_ source: String) -> String {
        if source.lowercased().hasPrefix("seed/") {
            return source.replacingOccurrences(of: "Seed/", with: "")
        }
        switch source.lowercased() {
        case "photos": return "Photos"
        case "pasted": return "Clipboard"
        case "seed": return "Seed"
        case "other": return "Other"
        default: return source
        }
    }

    private func sourceIcon(_ source: String) -> String {
        let key = source.lowercased()
        if key.hasPrefix("seed") { return "sparkles" }
        switch key {
        case "photos": return "photo.fill"
        case "pasted": return "doc.on.clipboard.fill"
        default: return "tray.full.fill"
        }
    }

    private func sourceColor(_ source: String) -> Color {
        let key = source.lowercased()
        if key.hasPrefix("seed") { return .purple }
        switch key {
        case "photos": return .blue
        case "pasted": return .teal
        default: return .gray
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
}

private struct LibraryStatistics {
    let photoCount: Int
    let albumCount: Int
    let averagePhotosPerAlbum: String?
    let libraryBytes: Int64
    let trashBytes: Int64
    let totalBytes: Int64
    let averageBytes: Int64?
    let ratedCount: Int
    let unratedCount: Int
    let averageRating: Double?
    let fiveStarCount: Int
    let addedThisWeek: Int
    let addedThisMonth: Int
    let oldestAddedAt: Date?
    let newestAddedAt: Date?
    let sourceCounts: [(name: String, count: Int)]

    init(images: [LibraryImage], albums: [Folder], libraryBytes: Int64, trashBytes: Int64) {
        photoCount = images.count
        albumCount = albums.count
        if albums.isEmpty {
            averagePhotosPerAlbum = nil
        } else {
            let average = Double(images.count) / Double(albums.count)
            averagePhotosPerAlbum = String(format: "%.1f", average)
        }

        self.libraryBytes = libraryBytes
        self.trashBytes = trashBytes
        totalBytes = libraryBytes + trashBytes

        let listedBytes = images.reduce(Int64(0)) { $0 + ($1.byteSize ?? 0) }
        averageBytes = images.isEmpty ? nil : listedBytes / Int64(images.count)

        let ratings = images.compactMap(\.rating)
        ratedCount = ratings.count
        unratedCount = images.count - ratings.count
        averageRating = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
        fiveStarCount = ratings.filter { $0 == 5 }.count

        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        addedThisWeek = images.filter { $0.createdAt >= weekAgo }.count
        addedThisMonth = images.filter { $0.createdAt >= monthStart }.count
        oldestAddedAt = images.map(\.createdAt).min()
        newestAddedAt = images.map(\.createdAt).max()

        var counts: [String: Int] = [:]
        for image in images {
            let key = image.sourceLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
            counts[key?.isEmpty == false ? key! : "other", default: 0] += 1
        }
        sourceCounts = counts
            .map { (name: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.name < rhs.name
                }
                return lhs.count > rhs.count
            }
    }
}
