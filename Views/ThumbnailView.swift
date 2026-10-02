//
//  ThumbnailView.swift
//  Fotoz
//

import SwiftUI

struct ThumbnailView: View {
    let image: LibraryImage
    let uiImage: UIImage?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color(.secondarySystemBackground)
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
    }
}
