//
//  SplitTitleView.swift
//  Fotoz
//

import SwiftUI

struct SplitTitleView: View {
    let title: String
    let splitIndex: Int
    let fontSize: CGFloat

    init(_ title: String, splitIndex: Int? = nil, fontSize: CGFloat = 28) {
        self.title = title
        self.fontSize = fontSize
        if let splitIndex {
            self.splitIndex = splitIndex
        } else {
            self.splitIndex = title.count / 2
        }
    }

    private var firstPart: String {
        String(title.prefix(splitIndex))
    }

    private var secondPart: String {
        String(title.suffix(title.count - splitIndex))
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(firstPart)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(.appRed)
            Text(secondPart)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(.appRed)
        }
    }
}

struct FotozWordmark: View {
    var font: Font = .headline.weight(.semibold)

    var body: some View {
        HStack(spacing: 0) {
            Text("F")
                .foregroundStyle(Color.appRed)
            Text("OTOZ")
        }
        .font(font)
        .accessibilityLabel("Fotoz")
    }
}
