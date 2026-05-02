//
//  ChipSetsView.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 3/7/26.
//

import SwiftUI

struct ChipSetsView: View {
    @Environment(\.dismiss) private var dismiss

    let currentChips: [SavedChipRow]
    let onLoad: ([SavedChipRow]) -> Void

    @State private var chipSets: [SavedNamedChipSet] = []
    @State private var newSetName: String = ""
    @State private var showSaveErrorAlert: Bool = false
    @State private var saveErrorMessage: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        CardView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SAVE CURRENT CHIP SET")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                Text("Save the chip colors, denominations, and quantities currently on your screen as a reusable set.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)

                                HStack {
                                    TextField("Example: Home Game Set", text: $newSetName)
                                        .textInputAutocapitalization(.words)
                                        .autocorrectionDisabled()
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                        )
                                        .cornerRadius(10)
                                        .foregroundStyle(AppColors.textPrimary)

                                    Button("Save") {
                                        saveCurrentSet()
                                    }
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(AppColors.accent)
                                    .foregroundStyle(.black)
                                    .cornerRadius(10)
                                }
                            }
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SAVED CHIP SETS")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                if chipSets.isEmpty {
                                    Text("No saved chip sets yet.")
                                        .foregroundStyle(AppColors.textSecondary)
                                } else {
                                    ForEach(chipSets) { chipSet in
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(chipSet.name)
                                                        .font(.headline)
                                                        .foregroundStyle(AppColors.textPrimary)

                                                    Text(summaryText(for: chipSet))
                                                        .font(.subheadline)
                                                        .foregroundStyle(AppColors.textSecondary)
                                                }

                                                Spacer()
                                            }

                                            HStack(spacing: 10) {
                                                Button {
                                                    onLoad(chipSet.chips)
                                                    dismiss()
                                                } label: {
                                                    Text("Load")
                                                        .fontWeight(.semibold)
                                                        .frame(maxWidth: .infinity)
                                                        .padding(.vertical, 10)
                                                        .background(AppColors.accent)
                                                        .foregroundStyle(.black)
                                                        .cornerRadius(10)
                                                }

                                                Button {
                                                    delete(chipSet.id)
                                                } label: {
                                                    Text("Delete")
                                                        .fontWeight(.semibold)
                                                        .frame(maxWidth: .infinity)
                                                        .padding(.vertical, 10)
                                                        .background(AppColors.card)
                                                        .foregroundStyle(.red)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 10)
                                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                                        )
                                                        .cornerRadius(10)
                                                }
                                            }

                                            Divider()
                                                .background(Color.white.opacity(0.08))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Chip Sets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                reload()
            }
            .alert("Unable to Save Chip Set", isPresented: $showSaveErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    private func reload() {
        chipSets = ChipSetStore.loadAll()
    }

    private func saveCurrentSet() {
        let trimmed = newSetName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            saveErrorMessage = "Enter a name for the chip set before saving."
            showSaveErrorAlert = true
            return
        }

        let usableChips = currentChips.filter { $0.quantity > 0 }

        guard !usableChips.isEmpty else {
            saveErrorMessage = "Create at least one chip color with a quantity greater than 0 before saving a chip set."
            showSaveErrorAlert = true
            return
        }

        ChipSetStore.save(name: trimmed, chips: currentChips)
        newSetName = ""
        reload()
    }

    private func delete(_ id: UUID) {
        ChipSetStore.delete(id: id)
        reload()
    }

    private func summaryText(for chipSet: SavedNamedChipSet) -> String {
        let count = chipSet.chips.count
        let totalQty = chipSet.chips.reduce(0) { $0 + $1.quantity }
        return "\(count) colors • \(totalQty) total chips"
    }
}
