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

                                HStack {
                                    TextField("Example: Home Game Set", text: $newSetName)
                                        .textInputAutocapitalization(.words)
                                        .autocorrectionDisabled()

                                    Button("Save") {
                                        saveCurrentSet()
                                    }
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(AppColors.accent)
                                    .foregroundStyle(.black)
                                    .cornerRadius(10)
                                    .disabled(newSetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || currentChips.isEmpty)
                                    .opacity((newSetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || currentChips.isEmpty) ? 0.6 : 1.0)
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
        }
    }

    private func reload() {
        chipSets = ChipSetStore.loadAll()
    }

    private func saveCurrentSet() {
        ChipSetStore.save(name: newSetName, chips: currentChips)
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
