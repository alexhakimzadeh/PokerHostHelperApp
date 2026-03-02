import SwiftUI

struct CashSetupView: View {

    // MARK: - Game State
    @State private var players: Int = 8

    // Buy-in in cents (slider snaps by $5 = 500 cents)
    @State private var buyInCents: Int = 2000 // $20 default
    private let buyInStepCents: Int = 500     // $5
    private let buyInMinCents: Int = 500      // $5
    private let buyInMaxCents: Int = 20000    // $200 (adjust anytime)

    @State private var reservePercent: Double = 0.30

    // MARK: - Blinds
    @State private var bigBlindCents: Int = 100 // $1.00 default

    // BB options per your requirement:
    private let bigBlindOptions: [Int] = [
        25, 50, 100, 200, 500, 1000, 2000
    ] // $0.25, $0.50, $1, $2, $5, $10, $20

    private var smallBlindCents: Int {
        // special case: BB 0.25 => SB 0.10
        if bigBlindCents == 25 { return 10 }
        return bigBlindCents / 2
    }

    // MARK: - Chip Setup
    // Start with no default chips
    @State private var chips: [ChipType] = []

    // Color picker options (edit/add anytime)
    private let chipColorOptions: [String] = [
        "White", "Red", "Blue", "Green", "Black",
        "Purple", "Yellow", "Orange", "Pink", "Brown", "Gray"
    ]

    // Denomination picklist options per your requirement
    private let chipDenomOptions: [Int] = [
        25, 50, 100, 200, 500, 1000, 2500, 5000, 10000, 50000
    ] // $0.25, $0.50, $1, $2, $5, $10, $25, $50, $100, $500

    // Quantity text buffer per chip row (because TextField wants String)
    @State private var qtyText: [UUID: String] = [:]

    // MARK: - Results
    @State private var result: AllocationResult? = nil

    // MARK: - Body
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    gameSection
                    blindsSection
                    chipsSection
                    calculateButton

                    if result != nil {
                        resultSection
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 4) {
            Text("POKER HOST")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundStyle(AppColors.textPrimary)

            Text("Cash Game Setup")
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Game Card
    private var gameSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("GAME")
                    .font(.caption)
                    .foregroundStyle(AppColors.accent)

                Stepper("Players: \(players)", value: $players, in: 1...50)
                    .foregroundStyle(AppColors.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Buy-in")
                        Spacer()
                        Text(Money.format(cents: buyInCents))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .foregroundStyle(AppColors.textPrimary)

                    Slider(
                        value: Binding(
                            get: { Double(buyInCents) },
                            set: { newValue in
                                let snapped = snap(Int(newValue), step: buyInStepCents)
                                buyInCents = clamp(snapped, min: buyInMinCents, max: buyInMaxCents)
                            }
                        ),
                        in: Double(buyInMinCents)...Double(buyInMaxCents),
                        step: Double(buyInStepCents)
                    )

                    HStack {
                        Text("Reserve: \(Int(reservePercent * 100))%")
                        Spacer()
                        Text("for rebuys")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Slider(value: $reservePercent, in: 0...0.70, step: 0.05)
                }
            }
        }
    }

    // MARK: - Blinds Card
    private var blindsSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("BLINDS")
                    .font(.caption)
                    .foregroundStyle(AppColors.accent)

                // (2) Big Blind label is explicit here
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

    // MARK: - Chips Card
    private var chipsSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("CHIPS")
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

                if chips.isEmpty {
                    Text("No chips added yet. Tap “Add Color”.")
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.top, 6)
                } else {
                    ForEach($chips) { $chip in
                        VStack(alignment: .leading, spacing: 10) {

                            HStack {
                                // (5) Color selectable
                                Picker("Color", selection: $chip.colorName) {
                                    ForEach(chipColorOptions, id: \.self) { color in
                                        Text(color).tag(color)
                                    }
                                }
                                .pickerStyle(.menu)

                                Spacer()

                                // Remove row
                                Button {
                                    removeChipRow(id: chip.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red.opacity(0.9))
                                }
                                .buttonStyle(.plain)
                            }
                            .foregroundStyle(AppColors.textPrimary)

                            HStack {
                                Text("Denomination")
                                Spacer()

                                // (1) Denomination is picklist with required options
                                Picker("", selection: $chip.denominationCents) {
                                    ForEach(chipDenomOptions, id: \.self) { cents in
                                        Text(Money.format(cents: cents)).tag(cents)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .foregroundStyle(AppColors.textPrimary)

                            HStack {
                                Text("Quantity")
                                Spacer()

                                TextField("0", text: Binding(
                                    get: { qtyText[chip.id] ?? String(chip.quantity) },
                                    set: { qtyText[chip.id] = $0 }
                                ))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 110)
                            }
                            .foregroundStyle(AppColors.textPrimary)

                            Divider()
                                .background(Color.white.opacity(0.08))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Calculate Button
    private var calculateButton: some View {
        Button(action: calculate) {
            Text("CALCULATE STACKS")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.accent)
                .foregroundColor(.black)
                .cornerRadius(12)
        }
        .disabled(chips.isEmpty)
        .opacity(chips.isEmpty ? 0.6 : 1.0)
    }

    // MARK: - Result Card
    private var resultSection: some View {
        guard let result else { return AnyView(EmptyView()) }

        return AnyView(
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("RESULTS")
                        .font(.caption)
                        .foregroundStyle(AppColors.accent)

                    HStack {
                        Text("Blinds")
                        Spacer()
                        Text("SB \(Money.format(cents: smallBlindCents)) • BB \(Money.format(cents: bigBlindCents))")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .foregroundStyle(AppColors.textPrimary)

                    Text("Per Player Total: \(result.perPlayerTotalString)")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    // Show per-player allocation (sorted by denom desc)
                    let sortedChips = chips.sorted(by: { $0.denominationCents > $1.denominationCents })
                    ForEach(sortedChips, id: \.self) { t in
                        let count = result.perPlayer[t] ?? 0
                        if count > 0 {
                            HStack {
                                Text("\(t.colorName) (\(Money.format(cents: t.denominationCents)))")
                                Spacer()
                                Text("\(count)")
                            }
                            .foregroundStyle(AppColors.textPrimary)
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    Text(result.message)
                        .foregroundStyle(result.feasible ? .green : .orange)
                }
            }
        )
    }

    // MARK: - Logic
    private func calculate() {
        // Commit quantities from text fields into model
        for i in chips.indices {
            let id = chips[i].id
            if let qText = qtyText[id] {
                let trimmed = qText.trimmingCharacters(in: .whitespacesAndNewlines)
                let q = Int(trimmed) ?? 0
                chips[i].quantity = max(0, q)
            }
        }

        // (You said blinds shouldn’t be assumed; they’re now explicitly chosen)
        let _ = smallBlindCents
        let _ = bigBlindCents

        result = ChipAllocator.allocate(
            chips: chips,
            players: players,
            buyInCents: buyInCents,
            reservePercent: reservePercent
        )
    }

    private func addChipRow() {
        // Choose the first color not already used, otherwise default to first option
        let used = Set(chips.map { $0.colorName })
        let color = chipColorOptions.first(where: { !used.contains($0) }) ?? (chipColorOptions.first ?? "Chip")

        // Default denom to $1, qty 0 — user will set
        let newChip = ChipType(colorName: color, denominationCents: 100, quantity: 0)
        chips.append(newChip)
        qtyText[newChip.id] = "0"
    }

    private func removeChipRow(id: UUID) {
        chips.removeAll { $0.id == id }
        qtyText[id] = nil
        // Clear results to avoid stale mapping when chip keys change
        result = nil
    }

    private func snap(_ value: Int, step: Int) -> Int {
        guard step > 0 else { return value }
        let remainder = value % step
        let down = value - remainder
        let up = down + step
        return (remainder < step / 2) ? down : up
    }

    private func clamp(_ value: Int, min: Int, max: Int) -> Int {
        Swift.max(min, Swift.min(max, value))
    }
}
