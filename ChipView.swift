//
//  ChipView.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 3/13/26.
//

import SwiftUI

struct ChipView: View {

    let denomination: Int
    let count: Int

    private var color: Color {
        switch denomination {
        case 25: return .white
        case 50: return .yellow
        case 100: return .blue
        case 200: return .green
        case 500: return .purple
        case 1000: return .orange
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text("$\(Double(denomination)/100, specifier: "%.2f") chips")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {

                    ForEach(0..<count, id: \.self) { _ in
                        Circle()
                            .fill(color)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.6), lineWidth: 1)
                            )
                    }

                }
            }
        }
    }
}
