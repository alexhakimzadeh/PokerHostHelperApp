//
//  HelpAboutView.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 3/4/26.
//

import SwiftUI
import Combine
import UIKit

enum DenominationMode: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case auto = "Auto Assign"

    var id: String { rawValue }
}

struct CashSetupView: View {

    private enum Field: Hashable {
        case buyIn
        case quantity(UUID)
    }

    // MARK: - Game State
    @State private var players: Int = 8
    @State private var buyInText: String = "20"
    @State private var reservePercent: Double = 0.30

    // MARK: - Blinds
    @State private var bigBlindCents: Int = 100

    private let bigBlindOptions: [Int] = [
        25, 50, 100, 200, 500, 1000, 2000
    ]

    private var smallBlindCents: Int {
        switch bigBlindCents {
        case 25: return 10
        case 500: return 200
        default: return bigBlindCents / 2
        }
    }

    // MARK: - Chips
    @State private var denominationMode: DenominationMode = .manual
    @State private var chips: [ChipType] = []

    private let chipColorOptions: [String] = [
        "White", "Red", "Blue", "Green", "Black",
        "Purple", "Yellow", "Orange", "Pink", "Brown", "Gray"
    ]

    private let chipDenomOptions: [Int] = [
        10, 25, 50, 100, 500, 1000, 2500, 5000, 10000, 50000
    ]

    @State private var qtyText: [UUID: String] = [:]

    // MARK: - Results
    @State private var result: AllocationResult? = nil
    @State private var showResultsSheet: Bool = false

    // MARK: - Help / UI
    @State private var showHelpSheet: Bool = false
    @State private var showChipSetsSheet: Bool = false
    @State private var showSaveChipSetAlert: Bool = false
    @State private var chipSetName: String = ""
    @State private var showSaveChipSetErrorAlert: Bool = false
    @State private var saveChipSetErrorMessage: String = ""

    // MARK: - Row Editing
    @State private var editingChipID: UUID? = nil

    // MARK: - Loading State
    @State private var isCalculating: Bool = false
    @State private var loadingTask: Task<Void, Never>? = nil
    @State private var loadingLogLines: [String] = ["Preparing calculation..."]

    private let minimumLoadingDisplayTime: UInt64 = 500_000_000

    private let loadingMessages: [String] = [
        "Reviewing chip inventory...",
        "Checking blind structure...",
        "Validating denomination rules...",
        "Building candidate stacks...",
        "Testing exact allocations...",
        "Scoring playable setups...",
        "Comparing low-chip coverage...",
        "Estimating rebuy reserve...",
        "Selecting best result...",
        "Finalizing output..."
    ]

    // MARK: - Keyboard
    @FocusState private var focusedField: Field?
    @State private var keyboardHeight: CGFloat = 0

    // MARK: - Validation
    private var validationMessages: [String] {
        var messages: [String] = []

        let colorCounts = Dictionary(grouping: chips.map(\.colorName), by: { $0 })
            .mapValues(\.count)

        let duplicates = colorCounts
            .filter { $0.value > 1 }
            .map(\.key)
            .sorted()

        if !duplicates.isEmpty {
            messages.append("Duplicate chip colors selected: \(duplicates.joined(separator: ", ")).")
        }

        for chip in chips {
            let rawQty = qtyText[chip.id] ?? String(chip.quantity)
            let trimmed = rawQty.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                messages.append("\(chip.colorName) quantity is empty.")
                continue
            }

            guard let qty = Int(trimmed), qty >= 0 else {
                messages.append("\(chip.colorName) quantity must be a whole number 0 or greater.")
                continue
            }

            if denominationMode == .manual && chip.denominationCents < smallBlindCents {
                messages.append("\(chip.colorName) denomination must be at least the small blind.")
            }

            if qty == 0 {
                messages.append("\(chip.colorName) quantity is 0.")
            }
        }

        return Array(Set(messages)).sorted()
    }

    private var hasBlockingValidation: Bool {
        !validationMessages.isEmpty
    }

    private var currentSavedChipRows: [SavedChipRow] {
        chips.map { chip in
            let rawQty = qtyText[chip.id] ?? String(chip.quantity)
            let qty = Int(rawQty.trimmingCharacters(in: .whitespacesAndNewlines)) ?? chip.quantity

            return SavedChipRow(
                colorName: chip.colorName,
                denominationCents: chip.denominationCents,
                quantity: max(0, qty)
            )
        }
    }

    private var hasUsableChipSetToSave: Bool {
        currentSavedChipRows.contains(where: { $0.quantity > 0 })
    }

    private var totalChipBankValueCents: Int {
        currentSavedChipRows.reduce(0) { partial, row in
            partial + (row.denominationCents * row.quantity)
        }
    }

    private var recommendedDenominations: [Int] {
        let candidates = [smallBlindCents, bigBlindCents, bigBlindCents * 5]
        let valid = candidates.compactMap { value in
            chipDenomOptions.first(where: { $0 >= value })
        }
        return Array(NSOrderedSet(array: valid)) as? [Int] ?? valid
    }

    private var editingChip: ChipType? {
        guard let editingChipID else { return nil }
        return chips.first(where: { $0.id == editingChipID })
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        header
                        actionBar
                        gameSection
                        blindsSection
                        recommendedDenomsSection
                        chipsSection
                        bankValueSection

                        if !validationMessages.isEmpty {
                            validationSection
                        }

                        calculateButton
                    }
                    .padding()
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 40 : 0)
                }
                .onTapGesture {
                    focusedField = nil
                }
                .onChange(of: focusedField) {
                    guard let targetID = scrollID(for: focusedField) else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }

                if isCalculating {
                    Color.black.opacity(0.42)
                        .ignoresSafeArea()

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            ProgressView()
                                .scaleEffect(1.1)
                                .tint(AppColors.accent)

                            Text("Running Optimizer")
                                .font(.headline)
                                .foregroundStyle(AppColors.textPrimary)

                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(loadingLogLines.enumerated()), id: \.offset) { index, line in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(">")
                                        .foregroundStyle(index == loadingLogLines.count - 1 ? AppColors.accent : AppColors.textSecondary)

                                    Text(line)
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundStyle(index == loadingLogLines.count - 1 ? AppColors.textPrimary : AppColors.textSecondary)
                                        .opacity(index == loadingLogLines.count - 1 ? 1.0 : 0.75)

                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 340, alignment: .leading)
                    .background(AppColors.card)
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
                    .padding(.horizontal, 24)
                }
            }
            .sheet(isPresented: $showHelpSheet) {
                HelpAboutView()
            }
            .sheet(isPresented: $showChipSetsSheet) {
                ChipSetsView(
                    currentChips: currentSavedChipRows,
                    onLoad: { savedRows in
                        applyChipSet(savedRows)
                    }
                )
            }
            .sheet(isPresented: $showResultsSheet) {
                if let result {
                    ResultsSheetView(
                        result: result,
                        chips: chips,
                        denominationMode: denominationMode,
                        smallBlindCents: smallBlindCents,
                        bigBlindCents: bigBlindCents,
                        currentSavedChipRows: currentSavedChipRows
                    )
                }
            }
            .sheet(item: Binding(
                get: { editingChip },
                set: { newValue in editingChipID = newValue?.id }
            )) { chip in
                EditChipRowSheetView(
                    chipColorOptions: chipColorOptions,
                    chipDenomOptions: chipDenomOptions,
                    smallBlindCents: smallBlindCents,
                    denominationMode: denominationMode,
                    colorName: chip.colorName,
                    denominationCents: chip.denominationCents,
                    quantityText: qtyText[chip.id] ?? String(chip.quantity),
                    onSave: { colorName, denominationCents, quantity in
                        updateChip(
                            id: chip.id,
                            colorName: colorName,
                            denominationCents: denominationCents,
                            quantity: quantity
                        )
                    }
                )
            }
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
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                loadSavedSetup()
            }
            .onChange(of: players) { saveCurrentSetup() }
            .onChange(of: buyInText) { saveCurrentSetup() }
            .onChange(of: reservePercent) { saveCurrentSetup() }
            .onChange(of: bigBlindCents) { saveCurrentSetup() }
            .onChange(of: denominationMode) { saveCurrentSetup() }
            .onChange(of: chips) { saveCurrentSetup() }
            .onChange(of: qtyText) { saveCurrentSetup() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                keyboardHeight = frame.height * 0.72
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 6) {
            Text("POKER STACK")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundStyle(AppColors.textPrimary)

            Text("Cash Game Setup")
                .foregroundStyle(AppColors.textSecondary)

            Text("Step 1: Set your game • Step 2: Add your chips • Step 3: Calculate")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var actionBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    resetSetup()
                } label: {
                    Text("New Setup")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.card)
                        .foregroundStyle(AppColors.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .cornerRadius(12)
                }

                Button {
                    chipSetName = ""
                    focusedField = nil

                    guard hasUsableChipSetToSave else {
                        saveChipSetErrorMessage = "Create at least one chip color with a quantity greater than 0 before saving a chip set."
                        showSaveChipSetErrorAlert = true
                        return
                    }

                    showSaveChipSetAlert = true
                } label: {
                    Text("Save Set")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.card)
                        .foregroundStyle(AppColors.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .cornerRadius(12)
                }
            }

            HStack(spacing: 12) {
                Button {
                    showChipSetsSheet = true
                } label: {
                    Text("Chip Sets")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.card)
                        .foregroundStyle(AppColors.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .cornerRadius(12)
                }

                Button {
                    showHelpSheet = true
                } label: {
                    Text("Help")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.card)
                        .foregroundStyle(AppColors.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Sections
    private var gameSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("STEP 1 • GAME")
                    .font(.caption)
                    .foregroundStyle(AppColors.accent)

                Text("Set your players, buy-in, and reserve. Tap the box to edit the buy-in.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                Stepper("Players: \(players)", value: $players, in: 1...50)
                    .foregroundStyle(AppColors.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Buy-in")
                        Spacer()
                        TextField("20", text: $buyInText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                            .cornerRadius(10)
                            .foregroundStyle(AppColors.textPrimary)
                            .focused($focusedField, equals: .buyIn)
                            .id("buyInField")
                    }
                    .foregroundStyle(AppColors.textPrimary)

                    HStack {
                        Text("Reserve: \(Int(reservePercent * 100))%")
                        Spacer()
                        Text("for rebuys")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .foregroundStyle(AppColors.textPrimary)

                    Slider(value: $reservePercent, in: 0...0.70, step: 0.05)
                }
            }
        }
    }

    private var blindsSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("STEP 2 • BLINDS")
                    .font(.caption)
                    .foregroundStyle(AppColors.accent)

                Text("Choose the big blind. Small blind updates automatically.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                HStack {
                    Text("Big Blind")
                    Spacer()

                    Picker("", selection: $bigBlindCents) {
                        ForEach(bigBlindOptions, id: \.self) { cents in
                            Text(Money.format(cents: cents)).tag(cents)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .foregroundStyle(AppColors.textPrimary)

                HStack {
                    Text("Small Blind")
                    Spacer()
                    Text(Money.format(cents: smallBlindCents))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .foregroundStyle(AppColors.textPrimary)
            }
        }
    }

    private var recommendedDenomsSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("RECOMMENDED DENOMINATIONS")
                    .font(.caption)
                    .foregroundStyle(AppColors.accent)

                Text("For this blind level, a strong starting mix is:")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                HStack(spacing: 10) {
                    ForEach(recommendedDenominations, id: \.self) { denom in
                        Text(Money.format(cents: denom))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppColors.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .cornerRadius(10)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            }
        }
    }

    private var chipsSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("STEP 3 • CHIPS")
                        .font(.caption)
                        .foregroundStyle(AppColors.accent)

                    Spacer()

                    Button {
                        addChipRow()
                    } label: {
                        Text("Add Color")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.accent.opacity(0.18))
                            .cornerRadius(10)
                    }
                }

                Text("Tap any chip row to edit its details in a cleaner editor.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                Picker("Denomination Mode", selection: $denominationMode) {
                    ForEach(DenominationMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if chips.isEmpty {
                    Text("No chips added yet. Tap “Add Color” to start building your inventory.")
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.top, 6)
                } else {
                    ForEach(chips) { chip in
                        Button {
                            editingChipID = chip.id
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(chip.colorName)
                                        .font(.headline)
                                    Spacer()
                                    Text(Money.format(cents: chip.denominationCents))
                                        .foregroundStyle(AppColors.textSecondary)
                                }

                                HStack {
                                    Text("Quantity")
                                    Spacer()
                                    Text(qtyText[chip.id] ?? String(chip.quantity))
                                        .fontWeight(.semibold)
                                }

                                Text("Tap to edit")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)

                                Divider()
                                    .background(Color.white.opacity(0.08))
                            }
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        resetChipInventory()
                    } label: {
                        Text("Reset Chip Inventory")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.card)
                            .foregroundStyle(.red)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .cornerRadius(12)
                    }
                    .disabled(chips.isEmpty)
                    .opacity(chips.isEmpty ? 0.6 : 1.0)
                }
            }
        }
    }

    private var bankValueSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("CHIP BANK")
                    .font(.caption)
                    .foregroundStyle(AppColors.accent)

                HStack {
                    Text("Total Chip Bank Value")
                    Spacer()
                    Text(Money.format(cents: totalChipBankValueCents))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .foregroundStyle(AppColors.textPrimary)
            }
        }
    }

    private var validationSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("FIX BEFORE CALCULATING")
                    .font(.caption)
                    .foregroundStyle(.orange)

                ForEach(validationMessages, id: \.self) { message in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(.orange)
                        Text(message)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                    }
                }
            }
        }
    }

    private var calculateButton: some View {
        Button(action: {
            Task {
                await calculate()
            }
        }) {
            Text("CALCULATE STACKS")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.accent)
                .foregroundColor(.black)
                .cornerRadius(12)
        }
        .disabled(chips.isEmpty || isCalculating || hasBlockingValidation)
        .opacity((chips.isEmpty || isCalculating || hasBlockingValidation) ? 0.6 : 1.0)
    }

    // MARK: - Logic
    private func calculate() async {
        focusedField = nil
        let startTime = DispatchTime.now()

        isCalculating = true
        startLoadingMessages()

        for i in chips.indices {
            let id = chips[i].id
            if let qText = qtyText[id] {
                let trimmed = qText.trimmingCharacters(in: .whitespacesAndNewlines)
                let q = Int(trimmed) ?? 0
                chips[i].quantity = max(0, q)
            }
        }

        guard let buyInCents = Money.cents(from: buyInText), buyInCents > 0 else {
            result = AllocationResult(
                perPlayer: [:],
                bankLeft: [:],
                perPlayerTotalCents: 0,
                feasible: false,
                message: "Enter a valid buy-in amount greater than $0.00.",
                score: Int.min,
                totalChipsPerPlayer: 0,
                lowChipCountPerPlayer: 0,
                blindPostsPossible: 0,
                reserveBankTotalCents: 0
            )

            await enforceMinimumLoadingTime(startTime: startTime)
            stopLoadingMessages()
            isCalculating = false
            showResultsSheet = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        let currentChips = chips
        let currentPlayers = players
        let currentReservePercent = reservePercent
        let currentSmallBlindCents = smallBlindCents
        let currentBigBlindCents = bigBlindCents
        let currentMode = denominationMode

        await Task.yield()

        let calculationResult: (updatedChips: [ChipType]?, allocation: AllocationResult) = await Task.detached(priority: .userInitiated) { @Sendable in
            if currentMode == .auto {
                let optimized = ChipAllocator.optimizeAuto(
                    chips: currentChips,
                    players: currentPlayers,
                    buyInCents: buyInCents,
                    reservePercent: currentReservePercent,
                    smallBlindCents: currentSmallBlindCents,
                    bigBlindCents: currentBigBlindCents
                )
                return (updatedChips: optimized.chips, allocation: optimized.allocation)
            } else {
                let allocation = ChipAllocator.allocate(
                    chips: currentChips,
                    players: currentPlayers,
                    buyInCents: buyInCents,
                    reservePercent: currentReservePercent,
                    smallBlindCents: currentSmallBlindCents,
                    bigBlindCents: currentBigBlindCents
                )
                return (updatedChips: nil, allocation: allocation)
            }
        }.value

        if let updatedChips = calculationResult.updatedChips {
            chips = updatedChips
            for chip in updatedChips {
                qtyText[chip.id] = String(chip.quantity)
            }
        }

        result = calculationResult.allocation
        saveCurrentSetup()

        await enforceMinimumLoadingTime(startTime: startTime)
        stopLoadingMessages()
        isCalculating = false
        showResultsSheet = true

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(calculationResult.allocation.feasible ? .success : .warning)
    }

    private func startLoadingMessages() {
        loadingTask?.cancel()
        loadingLogLines = ["Preparing calculation..."]

        loadingTask = Task {
            var index = 0

            while !Task.isCancelled {
                let nextLine = loadingMessages[index]

                await MainActor.run {
                    var updated = loadingLogLines
                    updated.append(nextLine)

                    if updated.count > 5 {
                        updated.removeFirst(updated.count - 5)
                    }

                    loadingLogLines = updated
                }

                index = (index + 1) % loadingMessages.count
                try? await Task.sleep(nanoseconds: 550_000_000)
            }
        }
    }

    private func stopLoadingMessages() {
        loadingTask?.cancel()
        loadingTask = nil
        loadingLogLines = ["Preparing calculation..."]
    }

    private func enforceMinimumLoadingTime(startTime: DispatchTime) async {
        let elapsed = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds

        if elapsed < minimumLoadingDisplayTime {
            let remaining = minimumLoadingDisplayTime - elapsed
            try? await Task.sleep(nanoseconds: remaining)
        }
    }

    // MARK: - Persistence
    private func saveCurrentSetup() {
        let savedChips = currentSavedChipRows

        let saved = SavedCashSetup(
            players: players,
            buyInText: buyInText,
            reservePercent: reservePercent,
            bigBlindCents: bigBlindCents,
            denominationModeRawValue: denominationMode.rawValue,
            chips: savedChips
        )

        CashSetupStore.save(saved)
    }

    private func loadSavedSetup() {
        guard let saved = CashSetupStore.load() else { return }

        players = saved.players
        buyInText = saved.buyInText
        reservePercent = saved.reservePercent
        bigBlindCents = saved.bigBlindCents
        denominationMode = DenominationMode(rawValue: saved.denominationModeRawValue) ?? .manual

        let rebuiltChips = saved.chips.map {
            ChipType(
                colorName: $0.colorName,
                denominationCents: $0.denominationCents == 200 ? 100 : $0.denominationCents,
                quantity: $0.quantity
            )
        }

        chips = rebuiltChips

        var rebuiltQtyText: [UUID: String] = [:]
        for chip in rebuiltChips {
            rebuiltQtyText[chip.id] = String(chip.quantity)
        }
        qtyText = rebuiltQtyText
    }

    private func resetSetup() {
        players = 8
        buyInText = "20"
        reservePercent = 0.30
        bigBlindCents = 100
        denominationMode = .manual
        chips = []
        qtyText = [:]
        result = nil
        showResultsSheet = false
        focusedField = nil
        stopLoadingMessages()
        CashSetupStore.clear()
    }

    private func resetChipInventory() {
        chips = []
        qtyText = [:]
        result = nil
        showResultsSheet = false
        saveCurrentSetup()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func applyChipSet(_ savedRows: [SavedChipRow]) {
        let rebuiltChips = savedRows.map {
            ChipType(
                colorName: $0.colorName,
                denominationCents: $0.denominationCents == 200 ? 100 : $0.denominationCents,
                quantity: $0.quantity
            )
        }

        chips = rebuiltChips

        var rebuiltQtyText: [UUID: String] = [:]
        for chip in rebuiltChips {
            rebuiltQtyText[chip.id] = String(chip.quantity)
        }
        qtyText = rebuiltQtyText

        result = nil
        showResultsSheet = false
        saveCurrentSetup()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

    private func updateChip(id: UUID, colorName: String, denominationCents: Int, quantity: Int) {
        guard let index = chips.firstIndex(where: { $0.id == id }) else { return }
        chips[index].colorName = colorName
        chips[index].denominationCents = denominationCents
        chips[index].quantity = quantity
        qtyText[id] = String(quantity)
        result = nil
        saveCurrentSetup()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Focus Helpers
    private func quantityFieldID(for id: UUID) -> String {
        "quantity-\(id.uuidString)"
    }

    private func scrollID(for field: Field?) -> String? {
        switch field {
        case .buyIn:
            return "buyInField"
        case .quantity(let id):
            return quantityFieldID(for: id)
        case .none:
            return nil
        }
    }

    // MARK: - Chip Row Helpers
    private func addChipRow() {
        let used = Set(chips.map { $0.colorName })
        let color = chipColorOptions.first(where: { !used.contains($0) }) ?? (chipColorOptions.first ?? "Chip")

        let defaultDenom = chipDenomOptions.first(where: { $0 >= smallBlindCents }) ?? smallBlindCents
        let newChip = ChipType(colorName: color, denominationCents: defaultDenom, quantity: 0)

        chips.append(newChip)
        qtyText[newChip.id] = "0"
        result = nil
        showResultsSheet = false
        saveCurrentSetup()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func removeChipRow(id: UUID) {
        chips.removeAll { $0.id == id }
        qtyText[id] = nil
        result = nil
        showResultsSheet = false
        saveCurrentSetup()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
