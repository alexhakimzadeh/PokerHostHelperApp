//
//  TournamentSetupView.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 3/25/26.
//

import SwiftUI

struct TournamentSetupView: View {
    private static let preferredTournamentColorOrder: [String] = [
        "white", "red", "blue", "green", "black",
        "purple", "yellow", "orange", "pink", "brown", "gray", "grey"
    ]

    private enum BlindSpeed: String, CaseIterable, Identifiable, Codable {
        case turbo = "Turbo"
        case regular = "Regular"

        var id: String { rawValue }

        var estimatedMinutesPerLevel: Int {
            switch self {
            case .turbo: return 12
            case .regular: return 20
            }
        }

        var targetBigBlinds: Int {
            switch self {
            case .turbo: return 60
            case .regular: return 100
            }
        }

        var description: String {
            switch self {
            case .turbo: return "Fast finish and shorter stacks."
            case .regular: return "More play and deeper decisions."
            }
        }
    }

    private enum Field: Hashable {
        case buyIn
        case quantity(UUID)
    }

    private struct PrizePayout: Identifiable, Hashable {
        let id = UUID()
        let place: String
        let amountCents: Int
        let percentage: Int
    }

    struct BlindLevel: Identifiable, Hashable {
        let level: Int
        let smallBlind: Int
        let bigBlind: Int
        let durationMinutes: Int

        var id: Int { level }
    }

    @State private var players = 8
    @State private var buyInText = "20"
    @State private var plannedLateRegistrations = 0
    @State private var plannedRebuys = 0
    @State private var plannedAddOns = 0
    @State private var addOnValueTexts: [String] = ["10", "20"]
    @State private var blindSpeed: BlindSpeed = .regular
    @State private var chips: [ChipType] = []
    @State private var qtyText: [UUID: String] = [:]
    @State private var showChipSetsSheet = false
    @State private var editingChipID: UUID? = nil
    @State private var showFollowUpNote = false
    @State private var showResultsSheet = false
    @State private var calculatedAllocation: AllocationResult? = nil
    @State private var calculatedChips: [ChipType] = []
    @State private var isCalculating = false
    @FocusState private var focusedField: Field?

    private let chipColorOptions: [String] = [
        "White", "Red", "Blue", "Green", "Black",
        "Purple", "Yellow", "Orange", "Pink", "Brown", "Gray"
    ]

    private let chipDenomOptions: [Int] = [
        25, 100, 500, 1000, 5000, 10000, 25000, 50000
    ]

    private let openingBlindOptions: [Int] = [
        25, 50, 100, 200, 500, 1000
    ]

    private var editingChip: ChipType? {
        guard let editingChipID else { return nil }
        return chips.first(where: { $0.id == editingChipID })
    }

    private var buyInCents: Int {
        Money.cents(from: buyInText) ?? 0
    }

    private var initialEntrants: Int {
        max(players + plannedLateRegistrations, 1)
    }

    private var totalPaidEntries: Int {
        max(initialEntrants + plannedRebuys + plannedAddOns, 1)
    }

    private var totalPrizePoolCents: Int {
        buyInCents * totalPaidEntries
    }

    private var parsedAddOnValueTexts: [String] {
        addOnValueTexts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { (Money.cents(from: $0) ?? 0) > 0 }
    }

    private var totalChipBankUnits: Int {
        currentSavedChipRows.reduce(0) { partial, row in
            partial + (row.denominationCents * row.quantity)
        }
    }

    private var chipsWithAppliedQuantities: [ChipType] {
        chips.map { chip in
            var updated = chip
            let quantity = Int((qtyText[chip.id] ?? String(chip.quantity)).trimmingCharacters(in: .whitespacesAndNewlines)) ?? chip.quantity
            updated.quantity = max(quantity, 0)
            return updated
        }
    }

    private var currentSavedChipRows: [SavedChipRow] {
        chipsWithAppliedQuantities.map { chip in
            SavedChipRow(
                colorName: chip.colorName,
                denominationCents: chip.denominationCents,
                quantity: chip.quantity
            )
        }
    }

    private var openingBigBlind: Int {
        let suggested = max(buyInCents / max(blindSpeed.targetBigBlinds, 1), openingBlindOptions.first ?? 25)
        return openingBlindOptions.last(where: { $0 <= suggested }) ?? (openingBlindOptions.first ?? 25)
    }

    private var openingSmallBlind: Int {
        max(openingBigBlind / 2, 25)
    }

    private var startingStackUnits: Int {
        calculatedAllocation?.perPlayerTotalCents ?? buyInCents
    }

    private var estimatedDurationText: String {
        let fieldFactor = max(initialEntrants - 1, 0)
        let stackFactor = max(startingStackUnits / max(openingBigBlind, 1), 1)
        let estimatedLevels = max(6, Int(round(Double(fieldFactor) * 0.8 + Double(stackFactor) * 0.08 + 4)))
        let totalMinutes = estimatedLevels * blindSpeed.estimatedMinutesPerLevel

        if totalMinutes >= 120 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes == 0 {
                return "\(hours) hr"
            }
            return "\(hours) hr \(minutes) min"
        }

        return "\(totalMinutes) min"
    }

    private var blindSchedule: [BlindLevel] {
        let smallBlindMultipliers: [Int]

        switch blindSpeed {
        case .turbo:
            smallBlindMultipliers = [
                1, 2, 3, 4, 6, 8, 10, 12, 16, 20,
                25, 30, 40, 50, 60, 80, 100, 125, 150, 200,
                250, 300, 400, 500, 600
            ]
        case .regular:
            smallBlindMultipliers = [
                1, 2, 3, 4, 5, 6, 8, 10, 12, 15,
                20, 25, 30, 40, 50, 60, 80, 100, 125, 150,
                200, 250, 300, 400, 500
            ]
        }

        return smallBlindMultipliers.enumerated().map { index, multiplier in
            BlindLevel(
                level: index + 1,
                smallBlind: openingSmallBlind * multiplier,
                bigBlind: openingBigBlind * multiplier,
                durationMinutes: blindSpeed.estimatedMinutesPerLevel
            )
        }
    }

    private var payoutBreakdown: [PrizePayout] {
        let percents: [Int]

        switch initialEntrants {
        case 0...2:
            percents = [100]
        case 3...4:
            percents = [70, 30]
        case 5...7:
            percents = [60, 30, 10]
        case 8...10:
            percents = [50, 30, 20]
        default:
            percents = [45, 25, 15, 10, 5]
        }

        var payouts: [PrizePayout] = []
        var awarded = 0

        for (index, percent) in percents.enumerated() {
            let rawAmount = (totalPrizePoolCents * percent) / 100
            let isLast = index == percents.count - 1
            let amount = isLast ? max(totalPrizePoolCents - awarded, 0) : rawAmount
            awarded += amount

            payouts.append(
                PrizePayout(
                    place: ordinal(index + 1),
                    amountCents: amount,
                    percentage: percent
                )
            )
        }

        return payouts
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if buyInCents <= 0 {
            messages.append("Enter a valid buy-in amount greater than $0.00.")
        }

        let duplicateColors = Dictionary(grouping: chips.map(\.colorName), by: { $0 })
            .filter { $0.value.count > 1 }
            .map(\.key)
            .sorted()

        if !duplicateColors.isEmpty {
            messages.append("Duplicate chip colors selected: \(duplicateColors.joined(separator: ", ")).")
        }

        for chip in chips {
            let quantity = Int((qtyText[chip.id] ?? String(chip.quantity)).trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1

            if quantity < 0 {
                messages.append("\(chip.colorName) quantity must be 0 or greater.")
            }

        }

        if !chips.contains(where: { (Int(qtyText[$0.id] ?? String($0.quantity)) ?? 0) > 0 }) {
            messages.append("Add at least one chip color with a quantity greater than 0.")
        }

        return Array(Set(messages)).sorted()
    }

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    fieldSection
                    chipSection

                    if !validationMessages.isEmpty {
                        validationSection
                    }

                    calculateButton
                    followUpButton
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)

            if isCalculating {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                CardView {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(AppColors.accent)

                        Text("Calculating Starting Stack")
                            .font(.headline)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Optimizing chip counts and building your blind structure.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: 260)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
        .navigationTitle("Tournament Beta")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChipSetsSheet) {
            ChipSetsView(currentChips: currentSavedChipRows) { savedRows in
                applyChipSet(savedRows)
            }
        }
        .sheet(isPresented: $showResultsSheet) {
            if let calculatedAllocation {
                TournamentResultsSheetView(
                    blindSpeed: blindSpeed.rawValue,
                    buyInText: Money.format(cents: buyInCents),
                    playerCount: totalPaidEntries,
                    allocation: calculatedAllocation,
                    chips: calculatedChips,
                    estimatedDurationText: estimatedDurationText,
                    blindSchedule: blindSchedule,
                    totalPrizePoolCents: totalPrizePoolCents,
                    startingPlayers: players,
                    plannedLateRegistrations: plannedLateRegistrations,
                    plannedRebuys: plannedRebuys,
                    plannedAddOns: plannedAddOns,
                    addOnValueTexts: parsedAddOnValueTexts
                )
            }
        }
        .sheet(
            isPresented: Binding(
                get: { editingChip != nil },
                set: { isPresented in
                    if !isPresented {
                        editingChipID = nil
                    }
                }
            )
        ) {
            if let chip = editingChip {
                EditChipRowSheetView(
                    chipColorOptions: chipColorOptions,
                    chipDenomOptions: chipDenomOptions,
                    smallBlindCents: openingSmallBlind,
                    denominationMode: .auto,
                    colorName: chip.colorName,
                    denominationCents: chip.denominationCents,
                    quantityText: qtyText[chip.id] ?? String(chip.quantity)
                ) { colorName, denominationCents, quantity in
                    updateChip(
                        id: chip.id,
                        colorName: colorName,
                        denominationCents: denominationCents,
                        quantity: quantity
                    )
                }
            }
        }
        .onAppear {
            loadSavedSetup()
        }
        .onChange(of: players) { handleSetupChange() }
        .onChange(of: buyInText) { handleSetupChange() }
        .onChange(of: plannedLateRegistrations) { handleSetupChange() }
        .onChange(of: plannedRebuys) { handleSetupChange() }
        .onChange(of: plannedAddOns) { handleSetupChange() }
        .onChange(of: addOnValueTexts) { handleSetupChange() }
        .onChange(of: blindSpeed) { handleSetupChange() }
        .onChange(of: qtyText) { handleSetupChange() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .alert("Subscription Follow-Up", isPresented: $showFollowUpNote) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("PokerStackPlus purchase wiring is intentionally still mocked. Keep this on the V2.0 release checklist before shipping.")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("TOURNAMENT MODE BETA")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundStyle(AppColors.textPrimary)

            Text("Build a tournament plan with smart blind suggestions, stack coverage, and automatic payouts. Beta testing is active.")
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var fieldSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("FIELD SETUP")
                    .font(.caption)
                    .foregroundStyle(AppColors.accent)

                Stepper("Starting Players: \(players)", value: $players, in: 2...50)
                    .foregroundStyle(AppColors.textPrimary)

                Stepper("Late Registrations: \(plannedLateRegistrations)", value: $plannedLateRegistrations, in: 0...20)
                    .foregroundStyle(AppColors.textPrimary)

                Stepper("Planned Rebuys: \(plannedRebuys)", value: $plannedRebuys, in: 0...40)
                    .foregroundStyle(AppColors.textPrimary)

                Stepper("Planned Add-Ons: \(plannedAddOns)", value: $plannedAddOns, in: 0...40)
                    .foregroundStyle(AppColors.textPrimary)

                HStack {
                    Text("Buy-In")
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    HStack(spacing: 8) {
                        Text("$")
                            .foregroundStyle(AppColors.textSecondary)

                        TextField("20", text: $buyInText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .foregroundStyle(AppColors.textPrimary)
                            .focused($focusedField, equals: .buyIn)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Blind Style")
                        .foregroundStyle(AppColors.textPrimary)

                    Picker("Blind Style", selection: $blindSpeed) {
                        ForEach(BlindSpeed.allCases) { speed in
                            Text(speed.rawValue).tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(blindSpeed.description)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                HStack {
                    Text("Chip Values")
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text("Auto assigned")
                        .foregroundStyle(AppColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Add-On Values")
                        .foregroundStyle(AppColors.textPrimary)

                    ForEach(Array(addOnValueTexts.enumerated()), id: \.offset) { index, _ in
                        HStack(spacing: 10) {
                            Text("$")
                                .foregroundStyle(AppColors.textSecondary)

                            TextField("20", text: Binding(
                                get: { addOnValueTexts[index] },
                                set: { addOnValueTexts[index] = $0 }
                            ))
                            .keyboardType(.decimalPad)
                            .foregroundStyle(AppColors.textPrimary)

                            Button(role: .destructive) {
                                guard addOnValueTexts.count > 1 else { return }
                                addOnValueTexts.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .cornerRadius(10)
                    }

                    Button("Add Add-On Value") {
                        addOnValueTexts.append(buyInText.isEmpty ? "10" : buyInText)
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.accent)
                }
            }
        }
    }

    private var chipSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("CHIP BANK")
                        .font(.caption)
                        .foregroundStyle(AppColors.accent)

                    Spacer()

                    Button("Chip Sets") {
                        showChipSetsSheet = true
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.card)
                    .foregroundStyle(AppColors.textPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .cornerRadius(10)

                    Button("Add Color") {
                        addChipRow()
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.accent.opacity(0.18))
                    .foregroundStyle(AppColors.accent)
                    .cornerRadius(10)
                }

                Text("Enter your chips the same way you do for cash games. Tournament Mode uses that bank to suggest equal starting stacks for every paid entry.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                if chips.isEmpty {
                    Text("No chips added yet. Tap Add Color to start building your tournament bank.")
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    ForEach(chipsWithAppliedQuantities) { chip in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(chip.colorName)
                                    .font(.headline)
                                    .foregroundStyle(AppColors.textPrimary)

                                Button("Edit Color") {
                                    editingChipID = chip.id
                                }
                                .font(.caption)
                                .foregroundStyle(AppColors.accent)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                if calculatedAllocation != nil {
                                    Text(formatTournamentUnits(chip.denominationCents))
                                        .font(.headline)
                                        .foregroundStyle(AppColors.textPrimary)
                                }

                                Text("Auto assigned")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)

                                TextField("Qty", text: Binding(
                                    get: { qtyText[chip.id] ?? String(chip.quantity) },
                                    set: { qtyText[chip.id] = $0 }
                                ))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 72)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )
                                .cornerRadius(10)
                                .foregroundStyle(AppColors.textPrimary)
                                .focused($focusedField, equals: .quantity(chip.id))
                            }
                        }
                        .padding(.vertical, 4)

                        Divider()
                            .background(Color.white.opacity(0.08))
                    }
                }

                HStack {
                    Text("Total Bank")
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text(formatTournamentUnits(totalChipBankUnits))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var planningSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("TOURNAMENT PLAN")
                    .font(.caption)
                    .foregroundStyle(AppColors.accent)

                summaryRow("Initial field", "\(initialEntrants) players")
                summaryRow("Paid entries covered", "\(totalPaidEntries) total")
                summaryRow("Prize pool", Money.format(cents: totalPrizePoolCents))
                summaryRow("Suggested opening blind", "\(formatTournamentUnits(openingSmallBlind)) / \(formatTournamentUnits(openingBigBlind))")
                summaryRow("Estimated duration", estimatedDurationText)

                if let allocation = calculatedAllocation {
                    summaryRow("Suggested starting stack", formatTournamentUnits(allocation.perPlayerTotalCents))
                    summaryRow("Chips per entry", "\(allocation.totalChipsPerPlayer)")
                    summaryRow("Bank left after all planned entries", formatTournamentUnits(allocation.reserveBankTotalCents))
                } else {
                    Text("Tap Calculate Starting Stack to generate the optimal chip breakdown and full blind structure.")
                        .foregroundStyle(AppColors.textSecondary)
                }

                Text("Blind suggestions only: no in-app timer will be added in this version.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var payoutsSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("AUTO PAYOUTS")
                    .font(.caption)
                    .foregroundStyle(AppColors.accent)

                Text("Winner-heavy defaults are based on your confirmed V2.0 rules.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                ForEach(payoutBreakdown) { payout in
                    HStack {
                        Text(payout.place)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text("\(payout.percentage)%")
                            .foregroundStyle(AppColors.textSecondary)
                        Text(Money.format(cents: payout.amountCents))
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(minWidth: 90, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var validationSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("FIX BEFORE RELYING ON THIS PLAN")
                    .font(.caption)
                    .foregroundStyle(.orange)

                ForEach(validationMessages, id: \.self) { message in
                    Text("• \(message)")
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var followUpButton: some View {
        Button {
            saveCurrentSetup()
            showFollowUpNote = true
        } label: {
            Text("Remember Subscription Follow-Up")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.accent)
                .foregroundStyle(.black)
                .cornerRadius(12)
        }
    }

    private var calculateButton: some View {
        Button {
            Task {
                await calculateOptimalStack()
            }
        } label: {
            Text("CALCULATE STARTING STACK")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.accent)
                .foregroundStyle(.black)
                .cornerRadius(12)
        }
        .disabled(!validationMessages.isEmpty || isCalculating)
        .opacity((validationMessages.isEmpty && !isCalculating) ? 1.0 : 0.6)
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func ordinal(_ value: Int) -> String {
        switch value {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(value)th"
        }
    }

    private func formatTournamentUnits(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    private func remapTournamentColors(
        chips: [ChipType],
        allocation: AllocationResult
    ) -> (chips: [ChipType], allocation: AllocationResult) {
        let activeChips = chips.filter { $0.quantity > 0 }
        guard !activeChips.isEmpty else { return (chips, allocation) }

        let sortedDenominations = activeChips.map(\.denominationCents).sorted()
        let chipsInPreferredColorOrder = activeChips.sorted { lhs, rhs in
            let lhsRank = preferredTournamentColorRank(lhs.colorName)
            let rhsRank = preferredTournamentColorRank(rhs.colorName)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.colorName < rhs.colorName
        }

        var remappedByID: [UUID: ChipType] = [:]
        for (index, chip) in chipsInPreferredColorOrder.enumerated() {
            var updated = chip
            updated.denominationCents = sortedDenominations[index]
            remappedByID[chip.id] = updated
        }

        let remappedChips = chips.map { remappedByID[$0.id] ?? $0 }
        let remappedPerPlayer = Dictionary(
            uniqueKeysWithValues: allocation.perPlayer.map { item in
                ((remappedByID[item.key.id] ?? item.key), item.value)
            }
        )
        let remappedBankLeft = Dictionary(
            uniqueKeysWithValues: allocation.bankLeft.map { item in
                ((remappedByID[item.key.id] ?? item.key), item.value)
            }
        )

        let remappedAllocation = AllocationResult(
            perPlayer: remappedPerPlayer,
            bankLeft: remappedBankLeft,
            perPlayerTotalCents: allocation.perPlayerTotalCents,
            feasible: allocation.feasible,
            message: allocation.message,
            score: allocation.score,
            totalChipsPerPlayer: allocation.totalChipsPerPlayer,
            lowChipCountPerPlayer: allocation.lowChipCountPerPlayer,
            blindPostsPossible: allocation.blindPostsPossible,
            reserveBankTotalCents: allocation.reserveBankTotalCents,
            maxSingleColorCountPerPlayer: allocation.maxSingleColorCountPerPlayer,
            colorsOverPreferredCapCount: allocation.colorsOverPreferredCapCount
        )

        return (remappedChips, remappedAllocation)
    }

    private func preferredTournamentColorRank(_ colorName: String) -> Int {
        let normalized = colorName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Self.preferredTournamentColorOrder.firstIndex(of: normalized) ?? Self.preferredTournamentColorOrder.count
    }

    private func calculateOptimalStack() async {
        focusedField = nil

        let activeChips = chipsWithAppliedQuantities.filter { $0.quantity > 0 }

        guard !activeChips.isEmpty, buyInCents > 0 else {
            return
        }

        isCalculating = true

        let currentPlayers = totalPaidEntries
        let currentBuyInCents = buyInCents
        let currentSmallBlind = openingSmallBlind
        let currentBigBlind = openingBigBlind
        let currentChips = activeChips

        let ranked = await Task.detached(priority: .userInitiated) { () -> RankedAllocationResult in
            await ChipAllocator.rankedAuto(
                chips: currentChips,
                players: currentPlayers,
                buyInCents: currentBuyInCents,
                reservePercent: 0,
                smallBlindCents: currentSmallBlind,
                bigBlindCents: currentBigBlind
            )
        }.value

        let remappedResult = remapTournamentColors(
            chips: ranked.primaryChips,
            allocation: ranked.primaryAllocation
        )

        calculatedAllocation = remappedResult.allocation
        calculatedChips = remappedResult.allocation.perPlayer.keys.sorted { $0.denominationCents > $1.denominationCents }

        let mappedChips = chips.map { chip in
            remappedResult.chips.first(where: { $0.id == chip.id }) ?? chip
        }
        chips = mappedChips
        qtyText = Dictionary(uniqueKeysWithValues: mappedChips.map { ($0.id, String($0.quantity)) })

        saveCurrentSetup()
        isCalculating = false
        showResultsSheet = true
    }

    private func handleSetupChange() {
        calculatedAllocation = nil
        calculatedChips = []
        saveCurrentSetup()
    }

    private func addChipRow() {
        let used = Set(chips.map(\.colorName))
        let color = chipColorOptions.first(where: { !used.contains($0) }) ?? "Chip"
        let denomination = chipDenomOptions.first ?? 25
        let chip = ChipType(colorName: color, denominationCents: denomination, quantity: 0)
        chips.append(chip)
        qtyText[chip.id] = "0"
        handleSetupChange()
    }

    private func updateChip(id: UUID, colorName: String, denominationCents: Int, quantity: Int) {
        guard let index = chips.firstIndex(where: { $0.id == id }) else { return }
        chips[index].colorName = colorName
        chips[index].denominationCents = denominationCents
        chips[index].quantity = quantity
        qtyText[id] = String(quantity)
        handleSetupChange()
    }

    private func applyChipSet(_ savedRows: [SavedChipRow]) {
        let rebuilt = savedRows.map {
            ChipType(colorName: $0.colorName, denominationCents: $0.denominationCents, quantity: $0.quantity)
        }

        chips = rebuilt
        qtyText = Dictionary(uniqueKeysWithValues: rebuilt.map { ($0.id, String($0.quantity)) })
        handleSetupChange()
    }

    private func saveCurrentSetup() {
        let saved = SavedTournamentSetup(
            players: players,
            buyInText: buyInText,
            plannedLateRegistrations: plannedLateRegistrations,
            plannedRebuys: plannedRebuys,
            plannedAddOns: plannedAddOns,
            addOnValueTexts: addOnValueTexts,
            blindSpeedRawValue: blindSpeed.rawValue,
            denominationModeRawValue: DenominationMode.auto.rawValue,
            chips: currentSavedChipRows
        )

        TournamentSetupStore.save(saved)
    }

    private func loadSavedSetup() {
        guard let saved = TournamentSetupStore.load() else { return }

        players = saved.players
        buyInText = saved.buyInText
        plannedLateRegistrations = saved.plannedLateRegistrations
        plannedRebuys = saved.plannedRebuys
        plannedAddOns = saved.plannedAddOns
        addOnValueTexts = saved.addOnValueTexts.isEmpty ? ["10", "20"] : saved.addOnValueTexts
        blindSpeed = BlindSpeed(rawValue: saved.blindSpeedRawValue) ?? .regular

        let rebuilt = saved.chips.map {
            ChipType(colorName: $0.colorName, denominationCents: $0.denominationCents, quantity: $0.quantity)
        }

        chips = rebuilt
        qtyText = Dictionary(uniqueKeysWithValues: rebuilt.map { ($0.id, String($0.quantity)) })
    }
}

private struct TournamentResultsSheetView: View {
    private struct ResultsPrizePayout: Identifiable {
        let id = UUID()
        let place: String
        let amountCents: Int
        let percentage: Int
    }

    @Environment(\.dismiss) private var dismiss

    let blindSpeed: String
    let buyInText: String
    let playerCount: Int
    let allocation: AllocationResult
    let chips: [ChipType]
    let estimatedDurationText: String
    let blindSchedule: [TournamentSetupView.BlindLevel]
    let totalPrizePoolCents: Int
    let startingPlayers: Int
    let plannedLateRegistrations: Int
    let plannedRebuys: Int
    let plannedAddOns: Int
    let addOnValueTexts: [String]

    @State private var extraPlayers = 0
    @State private var extraRebuys = 0
    @State private var extraAddOnCount = 0
    @State private var extraAddOnMoneyCents = 0
    @State private var extraAddOnChipUnits = 0
    @State private var showNegativeBankAlert = false
    @State private var showAddOnSheet = false
    @State private var showAddOnResultAlert = false
    @State private var addOnResultMessage = ""
    @State private var selectedAddOnValueText = ""

    private var buyInCents: Int {
        Money.cents(from: buyInText.replacingOccurrences(of: "$", with: "")) ?? 0
    }

    private var adjustedPaidEntries: Int {
        playerCount + extraPlayers + extraRebuys
    }

    private var adjustedPrizePoolCents: Int {
        totalPrizePoolCents + ((extraPlayers + extraRebuys) * buyInCents) + extraAddOnMoneyCents
    }

    private var adjustedBankLeftUnits: Int {
        allocation.reserveBankTotalCents - ((extraPlayers + extraRebuys) * allocation.perPlayerTotalCents) - extraAddOnChipUnits
    }

    private var parsedAddOnOptions: [Int] {
        addOnValueTexts.compactMap(Money.cents)
    }

    private var canRemovePlayer: Bool {
        extraPlayers > 0
    }

    private var canAddAnotherFullStack: Bool {
        adjustedBankLeftUnits - allocation.perPlayerTotalCents >= 0
    }

    private var adjustedPrizeBreakdown: [ResultsPrizePayout] {
        let percents: [Int]

        switch adjustedPaidEntries {
        case 0...2:
            percents = [100]
        case 3...4:
            percents = [70, 30]
        case 5...7:
            percents = [60, 30, 10]
        case 8...10:
            percents = [50, 30, 20]
        default:
            percents = [45, 25, 15, 10, 5]
        }

        var payouts: [ResultsPrizePayout] = []
        var awarded = 0

        for (index, percent) in percents.enumerated() {
            let rawAmount = (adjustedPrizePoolCents * percent) / 100
            let isLast = index == percents.count - 1
            let amount = isLast ? max(adjustedPrizePoolCents - awarded, 0) : rawAmount
            awarded += amount

            payouts.append(
                ResultsPrizePayout(
                    place: ordinal(index + 1),
                    amountCents: amount,
                    percentage: percent
                )
            )
        }

        return payouts
    }

    private var shareText: String {
        var lines: [String] = [
            "PokerStack Tournament Plan",
            "Format: \(blindSpeed)",
            "Buy-in: \(buyInText)",
            "Starting players: \(startingPlayers)",
            "Late registrations planned: \(plannedLateRegistrations)",
            "Planned rebuys: \(plannedRebuys + extraRebuys)",
            "Planned add-ons: \(plannedAddOns + extraAddOnCount)",
            "Paid entries: \(adjustedPaidEntries)",
            "Prize pool: \(Money.format(cents: adjustedPrizePoolCents))",
            "Starting stack: \(formatUnits(allocation.perPlayerTotalCents))",
            "Chips per player: \(allocation.totalChipsPerPlayer)",
            "Bank left: \(formatUnits(adjustedBankLeftUnits))",
            "20-chip soft cap: \(allocation.colorsOverPreferredCapCount == 0 ? "Met" : "\(allocation.colorsOverPreferredCapCount) color(s) over")",
            "Estimated duration: \(estimatedDurationText)",
            ""
        ]

        lines.append("Auto payouts:")
        for payout in adjustedPrizeBreakdown {
            lines.append("- \(payout.place): \(payout.percentage)% • \(Money.format(cents: payout.amountCents))")
        }

        lines.append("")
        lines.append("Starting stack breakdown:")
        for chip in chips {
            let count = allocation.perPlayer[chip] ?? 0
            if count > 0 {
                lines.append("- \(chip.colorName) \(formatUnits(chip.denominationCents)): \(count)")
            }
        }

        lines.append("")
        lines.append("25-level blind structure:")
        for level in blindSchedule {
            lines.append(
                "Level \(level.level): \(formatUnits(level.smallBlind)) / \(formatUnits(level.bigBlind)) • \(level.durationMinutes) min"
            )
        }

        return lines.joined(separator: "\n")
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
                                Text("OPTIMAL STARTING STACK")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                detailRow("Format", blindSpeed)
                                detailRow("Buy-in", buyInText)
                                detailRow("Starting players", "\(startingPlayers)")
                                detailRow("Late registrations", "\(plannedLateRegistrations)")
                                detailRow("Planned rebuys", "\(plannedRebuys + extraRebuys)")
                                detailRow("Planned add-ons", "\(plannedAddOns + extraAddOnCount)")
                                detailRow("Paid entries", "\(adjustedPaidEntries)")
                                detailRow("Prize pool", Money.format(cents: adjustedPrizePoolCents))
                                detailRow("Stack per player", formatUnits(allocation.perPlayerTotalCents))
                                detailRow("Chips per player", "\(allocation.totalChipsPerPlayer)")
                                detailRow("Bank left", formatUnits(adjustedBankLeftUnits))
                                detailRow(
                                    "20-chip soft cap",
                                    allocation.colorsOverPreferredCapCount == 0
                                        ? "Met"
                                        : "\(allocation.colorsOverPreferredCapCount) color(s) over"
                                )
                                detailRow("Estimated duration", estimatedDurationText)
                            }
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("QUICK UPDATES")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                HStack(spacing: 12) {
                                    Button {
                                        guard canAddAnotherFullStack else {
                                            showNegativeBankAlert = true
                                            return
                                        }
                                        extraPlayers += 1
                                    } label: {
                                        Text("Add Player")
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(AppColors.card)
                                            .foregroundStyle(AppColors.textPrimary)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                            )
                                            .cornerRadius(10)
                                    }

                                    Button {
                                        guard extraPlayers > 0 else { return }
                                        extraPlayers -= 1
                                    } label: {
                                        Text("Remove Player")
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(AppColors.card)
                                            .foregroundStyle(AppColors.textPrimary)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                            )
                                            .cornerRadius(10)
                                    }
                                    .disabled(!canRemovePlayer)
                                    .opacity(canRemovePlayer ? 1.0 : 0.5)

                                }

                                HStack(spacing: 12) {
                                    Button {
                                        guard canAddAnotherFullStack else {
                                            showNegativeBankAlert = true
                                            return
                                        }
                                        extraRebuys += 1
                                    } label: {
                                        Text("Add Rebuy")
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(AppColors.card)
                                            .foregroundStyle(AppColors.textPrimary)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                            )
                                            .cornerRadius(10)
                                    }

                                    Button {
                                        selectedAddOnValueText = addOnValueTexts.first ?? ""
                                        showAddOnSheet = true
                                    } label: {
                                        Text("Add Add-On")
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(AppColors.card)
                                            .foregroundStyle(AppColors.textPrimary)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                            )
                                            .cornerRadius(10)
                                    }
                                    .disabled(parsedAddOnOptions.isEmpty)
                                    .opacity(parsedAddOnOptions.isEmpty ? 0.5 : 1.0)
                                }
                            }
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("AUTO PAYOUTS")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                ForEach(adjustedPrizeBreakdown) { payout in
                                    HStack {
                                        Text(payout.place)
                                            .foregroundStyle(AppColors.textPrimary)
                                        Spacer()
                                        Text("\(payout.percentage)%")
                                            .foregroundStyle(AppColors.textSecondary)
                                        Text(Money.format(cents: payout.amountCents))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(AppColors.textPrimary)
                                    }
                                }
                            }
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("STARTING STACK BREAKDOWN")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                if allocation.feasible {
                                    ForEach(chips, id: \.self) { chip in
                                        let count = allocation.perPlayer[chip] ?? 0
                                        if count > 0 {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(chip.colorName)
                                                        .foregroundStyle(AppColors.textPrimary)
                                                    Text(formatUnits(chip.denominationCents))
                                                        .font(.subheadline)
                                                        .foregroundStyle(AppColors.textSecondary)
                                                }

                                                Spacer()

                                                Text("x\(count)")
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(AppColors.textPrimary)
                                            }
                                        }
                                    }
                                } else {
                                    Text(allocation.message)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                        }

                        CardView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("25-LEVEL BLIND STRUCTURE")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                ForEach(blindSchedule) { level in
                                    HStack {
                                        Text("Level \(level.level)")
                                            .foregroundStyle(AppColors.textPrimary)

                                        Spacer()

                                        Text("\(formatUnits(level.smallBlind)) / \(formatUnits(level.bigBlind))")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(AppColors.textPrimary)

                                        Text("• \(level.durationMinutes)m")
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Tournament Management Beta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }
            .alert("Bank Too Low", isPresented: $showNegativeBankAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("There are not enough chips left in the bank for another player, rebuy, or selected add-on.")
            }
            .alert("Add-On Ready", isPresented: $showAddOnResultAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(addOnResultMessage)
            }
            .sheet(isPresented: $showAddOnSheet) {
                TournamentAddOnSheetView(
                    addOnValueTexts: addOnValueTexts,
                    buyInCents: buyInCents,
                    chips: chips,
                    allocation: allocation,
                    onConfirm: { selectedText in
                        handleAddOnSelection(selectedText)
                    }
                )
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func ordinal(_ value: Int) -> String {
        switch value {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(value)th"
        }
    }

    private func formatUnits(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    private func handleAddOnSelection(_ selectedText: String) {
        guard let selectedCents = Money.cents(from: selectedText), buyInCents > 0 else { return }

        let chipUnits = targetChipUnits(for: selectedCents)

        guard adjustedBankLeftUnits - chipUnits >= 0 else {
            showNegativeBankAlert = true
            return
        }

        guard let chipBreakdown = addOnBreakdown(for: chipUnits) else {
            addOnResultMessage = "Unable to build an exact add-on stack for \(Money.format(cents: selectedCents)) from the current starting-stack composition."
            showAddOnResultAlert = true
            return
        }

        extraAddOnCount += 1
        extraAddOnMoneyCents += selectedCents
        extraAddOnChipUnits += chipUnits

        let chipLines = chipBreakdown.compactMap { chip, count -> String? in
            guard count > 0 else { return nil }
            return "\(chip.colorName) \(formatUnits(chip.denominationCents)): \(count)"
        }

        addOnResultMessage = """
        Collect \(Money.format(cents: selectedCents)).

        Give the player:
        \(chipLines.joined(separator: "\n"))
        """
        showAddOnResultAlert = true
    }

    private func targetChipUnits(for amountCents: Int) -> Int {
        max(1, Int((Double(allocation.perPlayerTotalCents) * Double(amountCents) / Double(buyInCents)).rounded()))
    }

    private func addOnBreakdown(for targetUnits: Int) -> [(chip: ChipType, count: Int)]? {
        let available = chips
            .compactMap { chip -> (chip: ChipType, maxCount: Int, idealCount: Double)? in
                let maxCount = allocation.perPlayer[chip] ?? 0
                guard maxCount > 0 else { return nil }
                let idealCount = Double(maxCount) * Double(targetUnits) / Double(allocation.perPlayerTotalCents)
                return (chip: chip, maxCount: maxCount, idealCount: idealCount)
            }
            .sorted { $0.chip.denominationCents > $1.chip.denominationCents }

        guard !available.isEmpty else { return nil }

        let suffixMax: [Int] = {
            var values = Array(repeating: 0, count: available.count + 1)
            for index in stride(from: available.count - 1, through: 0, by: -1) {
                values[index] = values[index + 1] + (available[index].chip.denominationCents * available[index].maxCount)
            }
            return values
        }()

        var bestCounts: [Int]? = nil
        var bestScore = Double.infinity
        var workingCounts = Array(repeating: 0, count: available.count)

        func dfs(_ index: Int, _ remaining: Int) {
            if remaining < 0 { return }
            if index == available.count {
                guard remaining == 0 else { return }
                let score = zip(workingCounts, available).reduce(0.0) { partial, pair in
                    let count = pair.0
                    let item = pair.1
                    return partial + abs(Double(count) - item.idealCount)
                }

                if score < bestScore {
                    bestScore = score
                    bestCounts = workingCounts
                }
                return
            }

            guard remaining <= suffixMax[index] else { return }

            let item = available[index]
            let denomination = item.chip.denominationCents
            let maxCount = min(item.maxCount, remaining / denomination)

            let candidates = (0...maxCount).sorted { lhs, rhs in
                abs(Double(lhs) - item.idealCount) < abs(Double(rhs) - item.idealCount)
            }

            for count in candidates {
                workingCounts[index] = count
                dfs(index + 1, remaining - (count * denomination))
            }

            workingCounts[index] = 0
        }

        dfs(0, targetUnits)

        guard let bestCounts else { return nil }

        return zip(available, bestCounts).map { item, count in
            (chip: item.chip, count: count)
        }
    }
}

private struct TournamentAddOnSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let addOnValueTexts: [String]
    let buyInCents: Int
    let chips: [ChipType]
    let allocation: AllocationResult
    let onConfirm: (String) -> Void

    @State private var selectedValueText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("ADD-ON")
                                .font(.caption)
                                .foregroundStyle(AppColors.accent)

                            HStack {
                                Text("Money Received")
                                    .foregroundStyle(AppColors.textPrimary)
                                Spacer()
                                Picker("", selection: $selectedValueText) {
                                    ForEach(addOnValueTexts, id: \.self) { value in
                                        Text("$\(value)").tag(value)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }

                    Button("Confirm Add-On") {
                        onConfirm(selectedValueText)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.accent)
                    .foregroundStyle(.black)
                    .cornerRadius(12)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Add-On")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedValueText = addOnValueTexts.first ?? ""
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    NavigationStack {
        TournamentSetupView()
    }
}
