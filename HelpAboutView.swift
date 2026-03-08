//
//  HelpAboutView.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 3/7/26.
//

import SwiftUI

struct HelpAboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("POKER STACK HELP")
                                    .font(.headline)
                                    .foregroundStyle(AppColors.textPrimary)

                                Text("PokerStack helps you quickly determine the best chip stack to give each player for a cash game while keeping enough chips in the bank for rebuys.")
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("HOW TO USE THE CALCULATOR")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                helpRow("1. Set the number of players, buy-in, reserve %, and blinds.")
                                helpRow("2. Add each chip color you have and enter the quantity.")
                                helpRow("3. Choose Manual or Auto Assign denominations.")
                                helpRow("4. Tap Calculate Stacks to see what each player should receive.")
                            }
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("MANUAL MODE")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                Text("In Manual Mode you choose the denomination for each chip color yourself. This is useful if your chip set already has fixed values.")
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("AUTO ASSIGN MODE")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                Text("Auto Assign lets PokerStack determine the most playable denomination assignment for your chips.")
                                    .foregroundStyle(AppColors.textSecondary)

                                helpRow("Uses the small blind as the minimum denomination.")
                                helpRow("Prefers setups with enough small chips to post blinds and make change.")
                                helpRow("Balances exact buy-in matching with stack playability.")
                            }
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("CHIP SETS")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                Text("Chip Sets allow you to save your chip inventory so you don't have to re-enter it every time you host a game.")
                                    .foregroundStyle(AppColors.textSecondary)

                                helpRow("Tap the Chip Sets button at the top of the screen.")
                                helpRow("Enter a name for your chip set and tap Save.")
                                helpRow("Your chip quantities and colors will be saved under that name.")
                                helpRow("Later you can open Chip Sets and tap Load to instantly restore that inventory.")
                                helpRow("You can also delete chip sets you no longer use.")
                            }
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("TIPS")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                helpRow("If no allocation is found, try lowering the reserve percentage.")
                                helpRow("More low-denomination chips usually improve results.")
                                helpRow("Try Auto Assign if you're unsure how to distribute denominations.")
                                helpRow("Saving your chip sets makes setup much faster for recurring games.")
                            }
                        }

                    }
                    .padding()
                }
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func helpRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(AppColors.accent)

            Text(text)
                .foregroundStyle(AppColors.textSecondary)

            Spacer()
        }
    }
}
