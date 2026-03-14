//
//  ResultsSheetsView.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 3/13/26.
//

import SwiftUI
import UIKit

struct ResultsSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let result: AllocationResult
    let chips: [ChipType]
    let denominationMode: DenominationMode
    let smallBlindCents: Int
    let bigBlindCents: Int
    let currentSavedChipRows: [SavedChipRow]

    @State private var showSaveChipSetAlert: Bool = false
    @State private var chipSetName: String = ""
    @State private var showSaveChipSetErrorAlert: Bool = false
    @State private var saveChipSetErrorMessage: String = ""

    private var sortedChips: [ChipType] {
        chips.sorted(by: { $0.denominationCents > $1.denominationCents })
    }

    private var hasUsableChipSetToSave: Bool {
        currentSavedChipRows.contains(where: { $0.quantity > 0 })
    }

    private var confidenceLabel: String {
        guard result.feasible else { return "Manual Adjustment Recommended" }

        if result.blindPostsPossible >= 6 && result.lowChipCountPerPlayer >= 10 {
            return "Optimal Allocation Found"
        } else if result.blindPostsPossible >= 3 && result.lowChipCountPerPlayer >= 6 {
            return "Strong Allocation Found"
        } else {
            return "Playable Allocation Found"
        }
    }

    private var confidenceColor: Color {
        guard result.feasible else { return .orange }

        if result.blindPostsPossible >= 6 && result.lowChipCountPerPlayer >= 10 {
            return .green
        } else if result.blindPostsPossible >= 3 && result.lowChipCountPerPlayer >= 6 {
            return AppColors.accent
        } else {
            return .yellow
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        CardView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("OPTIMAL STACK ALLOCATION")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                HStack {
                                    Text("Blinds")
                                    Spacer()
                                    Text("SB \(Money.format(cents: smallBlindCents)) • BB \(Money.format(cents: bigBlindCents))")
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                .foregroundStyle(AppColors.textPrimary)

                                HStack {
                                    Text("Allocation Confidence")
                                    Spacer()
                                    Text(confidenceLabel)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(confidenceColor)
                                }
                                .foregroundStyle(AppColors.textPrimary)

                                if result.feasible {
                                    Text("Give Each Player")
                                        .font(.headline)
                                        .foregroundStyle(AppColors.textPrimary)

                                    ForEach(sortedChips, id: \.self) { chip in
                                        let count = result.perPlayer[chip] ?? 0
                                        if count > 0 {
                                            HStack {
                                                Text("\(chip.colorName) (\(Money.format(cents: chip.denominationCents)))")
                                                Spacer()
                                                Text("\(count)")
                                            }
                                            .foregroundStyle(AppColors.textPrimary)
                                        }
                                    }

                                    HStack {
                                        Text("Per Player Stack Value")
                                        Spacer()
                                        Text(result.perPlayerTotalString)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                    .foregroundStyle(AppColors.textPrimary)

                                    Divider()
                                        .background(Color.white.opacity(0.08))

                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Stack Visualization")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(AppColors.textPrimary)

                                        ForEach(sortedChips, id: \.self) { chip in
                                            let count = result.perPlayer[chip] ?? 0
                                            if count > 0 {
                                                ChipVisualView(
                                                    colorName: chip.colorName,
                                                    denominationCents: chip.denominationCents,
                                                    count: count
                                                )
                                            }
                                        }
                                    }

                                    Divider()
                                        .background(Color.white.opacity(0.08))

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Why this works")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(AppColors.textPrimary)

                                        metricRow("Chips per player", "\(result.totalChipsPerPlayer)")
                                        metricRow("Low chips per player", "\(result.lowChipCountPerPlayer)")
                                        metricRow("Small blind posts possible", "\(result.blindPostsPossible)x")
                                        metricRow("Reserve bank left", result.reserveBankTotalString)
                                    }

                                    if denominationMode == .auto {
                                        Divider()
                                            .background(Color.white.opacity(0.08))

                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Assigned Denominations")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(AppColors.textPrimary)

                                            ForEach(chips, id: \.self) { chip in
                                                HStack {
                                                    Text(chip.colorName)
                                                    Spacer()
                                                    Text(Money.format(cents: chip.denominationCents))
                                                        .foregroundStyle(AppColors.textSecondary)
                                                }
                                                .foregroundStyle(AppColors.textPrimary)
                                            }
                                        }
                                    }

                                    Divider()
                                        .background(Color.white.opacity(0.08))

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Bank Left")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(AppColors.textPrimary)

                                        ForEach(sortedChips, id: \.self) { chip in
                                            let left = result.bankLeft[chip] ?? 0
                                            if left > 0 {
                                                HStack {
                                                    Text("\(chip.colorName) (\(Money.format(cents: chip.denominationCents)))")
                                                    Spacer()
                                                    Text("\(left)")
                                                        .foregroundStyle(AppColors.textSecondary)
                                                }
                                                .foregroundStyle(AppColors.textPrimary)
                                            }
                                        }
                                    }
                                }

                                Divider()
                                    .background(Color.white.opacity(0.08))

                                Text(result.message)
                                    .foregroundStyle(result.feasible ? .green : .orange)
                            }
                        }

                        HStack(spacing: 12) {
                            Button {
                                dismiss()
                            } label: {
                                Text("Close")
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
                            }

                            Button {
                                guard result.feasible else { return }

                                guard hasUsableChipSetToSave else {
                                    saveChipSetErrorMessage = "Create at least one chip color with a quantity greater than 0 before saving a chip set."
                                    showSaveChipSetErrorAlert = true
                                    return
                                }

                                chipSetName = ""
                                showSaveChipSetAlert = true
                            } label: {
                                Text("Save Set")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(result.feasible ? AppColors.accent : AppColors.card)
                                    .foregroundStyle(result.feasible ? .black : AppColors.textSecondary)
                                    .cornerRadius(12)
                            }
                            .disabled(!result.feasible)
                            .opacity(result.feasible ? 1.0 : 0.6)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Save Chip Set", isPresented: $showSaveChipSetAlert) {
                TextField("Example: Home Game Set", text: $chipSetName)

                Button("Cancel", role: .cancel) { }

                Button("Save") {
                    saveNamedChipSet()
                }
            } message: {
                Text("Save the current chip inventory as a reusable chip set.")
            }
            .alert("Unable to Save Chip Set", isPresented: $showSaveChipSetErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveChipSetErrorMessage)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(AppColors.textSecondary)
        }
        .foregroundStyle(AppColors.textPrimary)
    }

    private func saveNamedChipSet() {
        let trimmed = chipSetName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            saveChipSetErrorMessage = "Enter a name for the chip set before saving."
            showSaveChipSetErrorAlert = true
            return
        }

        guard hasUsableChipSetToSave else {
            saveChipSetErrorMessage = "Create at least one chip color with a quantity greater than 0 before saving a chip set."
            showSaveChipSetErrorAlert = true
            return
        }

        ChipSetStore.save(name: trimmed, chips: currentSavedChipRows)
        chipSetName = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
