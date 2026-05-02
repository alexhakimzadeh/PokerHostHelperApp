//
//  ContentView.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 2/27/26.
//

import SwiftUI

struct ContentView: View {
    @State private var showTournamentPaywall = false
    @State private var openTournamentSetup = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text("POKER STACK")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Choose your game setup")
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    VStack(spacing: 16) {
                        NavigationLink {
                            CashSetupView()
                        } label: {
                            homeButton(
                                title: "Cash Game",
                                subtitle: "Use the existing cash game stack builder."
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            showTournamentPaywall = true
                        } label: {
                            homeButton(
                                title: "Tournament",
                                subtitle: "PokerStackPlus preview • Beta",
                                badge: "PLUS"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationDestination(isPresented: $openTournamentSetup) {
                TournamentSetupView()
            }
        }
        .sheet(isPresented: $showTournamentPaywall) {
            TournamentPaywallView {
                showTournamentPaywall = false
                openTournamentSetup = true
            }
        }
    }

    private func homeButton(title: String, subtitle: String, badge: String? = nil) -> some View {
        CardView {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.textPrimary)

                        if let badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.accent.opacity(0.18))
                                .foregroundStyle(AppColors.accent)
                                .cornerRadius(999)
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)
            }
        }
    }
}

private struct TournamentPaywallView: View {
    @Environment(\.dismiss) private var dismiss

    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    Spacer()

                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("POKERSTACKPLUS")
                                .font(.caption)
                                .foregroundStyle(AppColors.accent)

                            Text("Tournament Mode Beta")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(AppColors.textPrimary)

                            Text("$1.99 per month")
                                .font(.headline)
                                .foregroundStyle(AppColors.textPrimary)

                            Text("Preview the paywall now and continue into Tournament Mode for testing.")
                                .foregroundStyle(AppColors.textSecondary)

                            Text("Includes tournament setup, winner-heavy payouts, smart blind suggestions, and chip-stack planning.")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)

                            Text("TODO: Replace this mocked flow with the real PokerStackPlus subscription purchase flow before release.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }

                    VStack(spacing: 12) {
                        Button {
                            onContinue()
                        } label: {
                            Text("Continue for Testing")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.accent)
                                .foregroundStyle(.black)
                                .cornerRadius(12)
                        }

                        Button {
                            dismiss()
                        } label: {
                            Text("Not Now")
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
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("PokerStackPlus")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    ContentView()
}
