//
//  EditChipRowSheetView.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 3/13/26.
//


import SwiftUI

struct EditChipRowSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let chipColorOptions: [String]
    let chipDenomOptions: [Int]
    let smallBlindCents: Int
    let denominationMode: DenominationMode

    @State var colorName: String
    @State var denominationCents: Int
    @State var quantityText: String

    let onSave: (String, Int, Int) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("EDIT CHIP")
                                .font(.caption)
                                .foregroundStyle(AppColors.accent)

                            HStack {
                                Text("Color")
                                Spacer()
                                Picker("", selection: $colorName) {
                                    ForEach(chipColorOptions, id: \.self) { color in
                                        Text(color).tag(color)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .foregroundStyle(AppColors.textPrimary)

                            if denominationMode == .manual {
                                HStack {
                                    Text("Denomination")
                                    Spacer()
                                    Picker("", selection: $denominationCents) {
                                        ForEach(chipDenomOptions.filter { $0 >= smallBlindCents }, id: \.self) { cents in
                                            Text(Money.format(cents: cents)).tag(cents)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                .foregroundStyle(AppColors.textPrimary)
                            } else {
                                HStack {
                                    Text("Denomination")
                                    Spacer()
                                    Text("Auto")
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                .foregroundStyle(AppColors.textPrimary)
                            }

                            HStack {
                                Text("Quantity")
                                Spacer()
                                TextField("0", text: $quantityText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 110)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                    )
                                    .cornerRadius(10)
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                            .foregroundStyle(AppColors.textPrimary)
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.card)
                        .foregroundStyle(AppColors.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .cornerRadius(12)

                        Button("Save") {
                            let qty = max(0, Int(quantityText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
                            onSave(colorName, denominationCents, qty)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent)
                        .foregroundStyle(.black)
                        .cornerRadius(12)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Edit Chip")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
