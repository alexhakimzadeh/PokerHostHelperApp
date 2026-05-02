//
//  ChipVisualView.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 3/13/26.
//

import SwiftUI

struct ChipVisualView: View {
    let colorName: String
    let denominationCents: Int
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                chipFace(size: 24)
                Text("\(colorName) • \(Money.format(cents: denominationCents))")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("x\(count)")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<min(count, 16), id: \.self) { _ in
                        chipFace(size: 22)
                    }

                    if count > 16 {
                        Text("+\(count - 16)")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.leading, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chipFace(size: CGFloat) -> some View {
        let base = colorForChip(named: colorName)

        ZStack {
            Circle()
                .fill(base)
                .frame(width: size, height: size)

            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: size * 0.10)
                .frame(width: size * 0.82, height: size * 0.82)

            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: size * 0.05)
                .frame(width: size, height: size)

            Circle()
                .fill(base.opacity(0.9))
                .frame(width: size * 0.40, height: size * 0.40)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.55), lineWidth: size * 0.04)
                )
        }
    }

    private func colorForChip(named name: String) -> Color {
        switch name.lowercased() {
        case "white": return Color.white
        case "red": return Color.red
        case "blue": return Color.blue
        case "green": return Color.green
        case "black": return Color.black
        case "purple": return Color.purple
        case "yellow": return Color.yellow
        case "orange": return Color.orange
        case "pink": return Color.pink
        case "brown": return Color.brown
        case "gray", "grey": return Color.gray
        default: return AppColors.accent
        }
    }
}
