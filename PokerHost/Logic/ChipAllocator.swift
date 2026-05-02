//
//  LogicChipAllocator.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 2/27/26.
//

import Foundation

struct AllocationResult: Sendable {
    var perPlayer: [ChipType: Int]
    var bankLeft: [ChipType: Int]
    var perPlayerTotalCents: Int
    var feasible: Bool
    var message: String
    var score: Int

    var totalChipsPerPlayer: Int
    var lowChipCountPerPlayer: Int
    var blindPostsPossible: Int
    var reserveBankTotalCents: Int
    var maxSingleColorCountPerPlayer: Int
    var colorsOverPreferredCapCount: Int

    var perPlayerTotalString: String { Money.format(cents: perPlayerTotalCents) }
    var reserveBankTotalString: String { Money.format(cents: reserveBankTotalCents) }
}

struct AllocationRecommendation: Identifiable, Sendable {
    let id: UUID
    let label: String
    let summary: String
    let highlights: [String]
    let chips: [ChipType]
    let allocation: AllocationResult

    init(
        id: UUID = UUID(),
        label: String,
        summary: String,
        highlights: [String],
        chips: [ChipType],
        allocation: AllocationResult
    ) {
        self.id = id
        self.label = label
        self.summary = summary
        self.highlights = highlights
        self.chips = chips
        self.allocation = allocation
    }
}

struct AutoOptimizationResult: Sendable {
    var chips: [ChipType]
    var allocation: AllocationResult
}

struct RankedAllocationResult: Sendable {
    var primaryChips: [ChipType]
    var primaryAllocation: AllocationResult
    var recommendations: [AllocationRecommendation]
}

enum ChipAllocator: Sendable {

    private static let preferredColorOrder: [String] = [
        "white", "red", "blue", "green", "black",
        "purple", "yellow", "orange", "pink", "brown", "gray", "grey"
    ]

    static let availableDenoms: [Int] = [
        25, 50, 100, 500, 1000, 2500, 5000, 10000, 25000, 50000
    ]

    static func allocate(
        chips: [ChipType],
        players: Int,
        buyInCents: Int,
        reservePercent: Double,
        smallBlindCents: Int,
        bigBlindCents: Int
    ) -> AllocationResult {
        rankedManual(
            chips: chips,
            players: players,
            buyInCents: buyInCents,
            reservePercent: reservePercent,
            smallBlindCents: smallBlindCents,
            bigBlindCents: bigBlindCents
        ).primaryAllocation
    }

    static func rankedManual(
        chips: [ChipType],
        players: Int,
        buyInCents: Int,
        reservePercent: Double,
        smallBlindCents: Int,
        bigBlindCents: Int
    ) -> RankedAllocationResult {
        let allocations = topManualAllocations(
            chips: chips,
            players: players,
            buyInCents: buyInCents,
            reservePercent: reservePercent,
            smallBlindCents: smallBlindCents,
            bigBlindCents: bigBlindCents,
            limit: 3
        )

        if let primary = allocations.first {
            let recommendations = buildRecommendations(
                candidates: allocations.map { (chips: chips, allocation: $0) },
                buyInCents: buyInCents,
                reservePercent: reservePercent
            )

            return RankedAllocationResult(
                primaryChips: chips,
                primaryAllocation: primary,
                recommendations: recommendations
            )
        }

        let failure = manualFailureResult(
            chips: chips,
            players: players,
            buyInCents: buyInCents,
            reservePercent: reservePercent,
            smallBlindCents: smallBlindCents,
            bigBlindCents: bigBlindCents
        )

        return RankedAllocationResult(
            primaryChips: chips,
            primaryAllocation: failure,
            recommendations: [
                AllocationRecommendation(
                    label: "Best",
                    summary: "No exact playable stack found with the current setup.",
                    highlights: [],
                    chips: chips,
                    allocation: failure
                )
            ]
        )
    }

    static func optimizeAuto(
        chips: [ChipType],
        players: Int,
        buyInCents: Int,
        reservePercent: Double,
        smallBlindCents: Int,
        bigBlindCents: Int
    ) -> AutoOptimizationResult {
        let ranked = rankedAuto(
            chips: chips,
            players: players,
            buyInCents: buyInCents,
            reservePercent: reservePercent,
            smallBlindCents: smallBlindCents,
            bigBlindCents: bigBlindCents
        )

        return AutoOptimizationResult(
            chips: ranked.primaryChips,
            allocation: ranked.primaryAllocation
        )
    }

    static func rankedAuto(
        chips: [ChipType],
        players: Int,
        buyInCents: Int,
        reservePercent: Double,
        smallBlindCents: Int,
        bigBlindCents: Int
    ) -> RankedAllocationResult {
        let activeChips = chips.filter { $0.quantity > 0 }
        guard !activeChips.isEmpty else {
            let failure = emptyResult("Add at least one chip color with a quantity greater than 0.")
            return RankedAllocationResult(
                primaryChips: chips,
                primaryAllocation: failure,
                recommendations: [
                    AllocationRecommendation(
                        label: "Best",
                        summary: "Add at least one chip color with a quantity greater than 0.",
                        highlights: [],
                        chips: chips,
                        allocation: failure
                    )
                ]
            )
        }

        let pool = candidateDenoms(
            smallBlindCents: smallBlindCents,
            bigBlindCents: bigBlindCents,
            buyInCents: buyInCents,
            colorCount: activeChips.count
        )

        guard pool.count >= activeChips.count else {
            let msg = buildFailureMessage(
                base: "There are not enough valid denomination options for the selected colors and blind level.",
                chips: activeChips,
                availablePerType: [:],
                players: players,
                buyInCents: buyInCents,
                reservePercent: reservePercent,
                smallBlindCents: smallBlindCents,
                bigBlindCents: bigBlindCents,
                totalAvailableValue: 0,
                totalRequiredValue: players * buyInCents,
                mode: "auto"
            )
            let failure = emptyResult(msg)
            return RankedAllocationResult(
                primaryChips: chips,
                primaryAllocation: failure,
                recommendations: [
                    AllocationRecommendation(
                        label: "Best",
                        summary: "Auto-assign could not create a valid denomination mix for this setup.",
                        highlights: [],
                        chips: chips,
                        allocation: failure
                    )
                ]
            )
        }

        let searchOrder = activeChips.sorted {
            if $0.quantity != $1.quantity { return $0.quantity > $1.quantity }
            if $0.colorName != $1.colorName { return $0.colorName < $1.colorName }
            return $0.id.uuidString < $1.id.uuidString
        }

        var candidates: [(chips: [ChipType], allocation: AllocationResult)] = []
        var seenSignatures = Set<String>()
        var currentAssignment: [Int] = []
        var used = Set<Int>()

        func backtrack(_ index: Int) {
            if index == searchOrder.count {
                var assignedChips: [ChipType] = []

                for (idx, chip) in searchOrder.enumerated() {
                    var updated = chip
                    updated.denominationCents = currentAssignment[idx]
                    assignedChips.append(updated)
                }

                let rankedManual = rankedManual(
                    chips: assignedChips,
                    players: players,
                    buyInCents: buyInCents,
                    reservePercent: reservePercent,
                    smallBlindCents: smallBlindCents,
                    bigBlindCents: bigBlindCents
                )

                let allocation = rankedManual.primaryAllocation
                if allocation.feasible {
                    let signature = autoCandidateSignature(chips: assignedChips, allocation: allocation)
                    if seenSignatures.insert(signature).inserted {
                        insertCandidate(
                            (chips: assignedChips, allocation: allocation),
                            into: &candidates,
                            limit: 3
                        )
                    }
                }

                return
            }

            let minimumDenomForThisSlot: Int? = {
                guard index > 0 else { return nil }
                guard searchOrder[index].quantity == searchOrder[index - 1].quantity else { return nil }
                return currentAssignment[index - 1]
            }()

            for denom in pool {
                if used.contains(denom) { continue }
                if let minimumDenomForThisSlot, denom < minimumDenomForThisSlot { continue }

                used.insert(denom)
                currentAssignment.append(denom)
                backtrack(index + 1)
                currentAssignment.removeLast()
                used.remove(denom)
            }
        }

        backtrack(0)

        if let primary = candidates.first {
            let primaryChips = chips.map { baseChip in
                mappedCandidateChip(baseChip, using: primary.chips)
            }

            let mappedCandidates = candidates.map { candidate in
                (
                    chips: chips.map { baseChip in
                        mappedCandidateChip(baseChip, using: candidate.chips)
                    },
                    allocation: candidate.allocation
                )
            }

            let recommendations = buildRecommendations(
                candidates: mappedCandidates,
                buyInCents: buyInCents,
                reservePercent: reservePercent
            )

            return RankedAllocationResult(
                primaryChips: primaryChips,
                primaryAllocation: primary.allocation,
                recommendations: recommendations
            )
        }

        let msg = buildFailureMessage(
            base: "No exact playable auto-assignment found.",
            chips: activeChips,
            availablePerType: [:],
            players: players,
            buyInCents: buyInCents,
            reservePercent: reservePercent,
            smallBlindCents: smallBlindCents,
            bigBlindCents: bigBlindCents,
            totalAvailableValue: 0,
            totalRequiredValue: players * buyInCents,
            mode: "auto"
        )
        let failure = emptyResult(msg)
        return RankedAllocationResult(
            primaryChips: chips,
            primaryAllocation: failure,
            recommendations: [
                AllocationRecommendation(
                    label: "Best",
                    summary: "Auto-assign could not find an exact playable stack for this setup.",
                    highlights: [],
                    chips: chips,
                    allocation: failure
                )
            ]
        )
    }

    private static func topManualAllocations(
        chips: [ChipType],
        players: Int,
        buyInCents: Int,
        reservePercent: Double,
        smallBlindCents: Int,
        bigBlindCents: Int,
        limit: Int
    ) -> [AllocationResult] {
        guard players > 0, buyInCents > 0 else { return [] }

        let usableChips = chips.filter { $0.quantity > 0 && $0.denominationCents > 0 }
        guard !usableChips.isEmpty else { return [] }

        let sorted = usableChips.sorted { $0.denominationCents > $1.denominationCents }

        var availablePerType: [ChipType: Int] = [:]
        for chip in sorted {
            let reserved = Int(Double(chip.quantity) * reservePercent)
            availablePerType[chip] = max(0, chip.quantity - reserved)
        }

        let totalAvailableValue = sorted.reduce(0) { partial, chip in
            partial + chip.denominationCents * availablePerType[chip, default: 0]
        }
        let totalRequired = players * buyInCents
        guard totalAvailableValue >= totalRequired else { return [] }

        let perPlayerMax = sorted.map { availablePerType[$0, default: 0] / players }
        let suffixMaxValue = buildSuffixMaxValue(chips: sorted, perPlayerMax: perPlayerMax)

        var topResults: [AllocationResult] = []
        var seenSignatures = Set<String>()
        var currentCounts = Array(repeating: 0, count: sorted.count)

        func dfs(_ index: Int, _ remaining: Int) {
            if remaining < 0 { return }

            if index == sorted.count {
                guard remaining == 0 else { return }

                let allocation = Dictionary(
                    uniqueKeysWithValues: zip(sorted, currentCounts).filter { $0.1 > 0 }
                )

                guard canMakeAmount(target: smallBlindCents, allocation: allocation) else {
                    return
                }

                let result = buildAllocationResult(
                    totalChips: chips,
                    allocation: allocation,
                    players: players,
                    buyInCents: buyInCents,
                    smallBlindCents: smallBlindCents,
                    bigBlindCents: bigBlindCents
                )

                let signature = manualAllocationSignature(result)
                if seenSignatures.insert(signature).inserted {
                    insertAllocation(result, into: &topResults, limit: limit)
                }
                return
            }

            if remaining > suffixMaxValue[index] { return }

            let chip = sorted[index]
            let denom = chip.denominationCents
            let maxCount = min(perPlayerMax[index], remaining / denom)

            for count in stride(from: maxCount, through: 0, by: -1) {
                currentCounts[index] = count
                dfs(index + 1, remaining - (count * denom))
            }

            currentCounts[index] = 0
        }

        dfs(0, buyInCents)
        return topResults
    }

    private static func buildAllocationResult(
        totalChips: [ChipType],
        allocation: [ChipType: Int],
        players: Int,
        buyInCents: Int,
        smallBlindCents: Int,
        bigBlindCents: Int
    ) -> AllocationResult {
        let totalPerPlayer = allocation.reduce(0) { $0 + ($1.key.denominationCents * $1.value) }
        let bankLeft = computeBankLeft(total: totalChips, perPlayer: allocation, players: players)
        let totalChipsPerPlayer = allocation.values.reduce(0, +)
        let lowChipCount = allocation
            .filter { $0.key.denominationCents <= bigBlindCents }
            .map(\.value)
            .reduce(0, +)
        let blindPosts = maxBlindPostsPossible(
            smallBlindCents: smallBlindCents,
            allocation: allocation,
            cap: 12
        )
        let reserveBankTotal = bankLeft.reduce(0) { partial, item in
            partial + (item.key.denominationCents * item.value)
        }
        let maxSingleColorCount = allocation.values.max() ?? 0
        let colorsOverPreferredCapCount = allocation.values.filter { $0 > 20 }.count

        return AllocationResult(
            perPlayer: allocation,
            bankLeft: bankLeft,
            perPlayerTotalCents: totalPerPlayer,
            feasible: true,
            message: "Optimal allocation found.",
            score: scoreAllocation(
                allocation: allocation,
                buyInCents: buyInCents,
                smallBlindCents: smallBlindCents,
                bigBlindCents: bigBlindCents
            ),
            totalChipsPerPlayer: totalChipsPerPlayer,
            lowChipCountPerPlayer: lowChipCount,
            blindPostsPossible: blindPosts,
            reserveBankTotalCents: reserveBankTotal,
            maxSingleColorCountPerPlayer: maxSingleColorCount,
            colorsOverPreferredCapCount: colorsOverPreferredCapCount
        )
    }

    private static func manualFailureResult(
        chips: [ChipType],
        players: Int,
        buyInCents: Int,
        reservePercent: Double,
        smallBlindCents: Int,
        bigBlindCents: Int
    ) -> AllocationResult {
        guard players > 0, buyInCents > 0 else {
            return emptyResult("Players and buy-in must be greater than 0.")
        }

        let usableChips = chips.filter { $0.quantity > 0 && $0.denominationCents > 0 }
        guard !usableChips.isEmpty else {
            return emptyResult("Add at least one chip color with a quantity greater than 0.")
        }

        let sorted = usableChips.sorted { $0.denominationCents > $1.denominationCents }
        var availablePerType: [ChipType: Int] = [:]
        for chip in sorted {
            let reserved = Int(Double(chip.quantity) * reservePercent)
            availablePerType[chip] = max(0, chip.quantity - reserved)
        }

        let totalAvailableValue = sorted.reduce(0) { partial, chip in
            partial + chip.denominationCents * availablePerType[chip, default: 0]
        }
        let totalRequired = players * buyInCents

        if totalAvailableValue < totalRequired {
            let message = buildFailureMessage(
                base: "Not enough total chip value after reserve.",
                chips: usableChips,
                availablePerType: availablePerType,
                players: players,
                buyInCents: buyInCents,
                reservePercent: reservePercent,
                smallBlindCents: smallBlindCents,
                bigBlindCents: bigBlindCents,
                totalAvailableValue: totalAvailableValue,
                totalRequiredValue: totalRequired,
                mode: "manual"
            )
            return emptyResult(message)
        }

        let message = buildFailureMessage(
            base: "No exact playable allocation found.",
            chips: usableChips,
            availablePerType: availablePerType,
            players: players,
            buyInCents: buyInCents,
            reservePercent: reservePercent,
            smallBlindCents: smallBlindCents,
            bigBlindCents: bigBlindCents,
            totalAvailableValue: totalAvailableValue,
            totalRequiredValue: totalRequired,
            mode: "manual"
        )
        return emptyResult(message)
    }

    private static func buildRecommendations(
        candidates: [(chips: [ChipType], allocation: AllocationResult)],
        buyInCents: Int,
        reservePercent: Double
    ) -> [AllocationRecommendation] {
        let unique = Array(candidates.prefix(3))
        let labels = unique.count == 1 ? ["Best"] : (unique.count == 2 ? ["Best", "Good"] : ["Best", "Better", "Good"])

        let minChipCount = unique.map { $0.allocation.totalChipsPerPlayer }.min() ?? 0
        let maxBlindCoverage = unique.map { $0.allocation.blindPostsPossible }.max() ?? 0
        let maxReserve = unique.map { $0.allocation.reserveBankTotalCents }.max() ?? 0

        return unique.enumerated().map { index, candidate in
            let allocation = candidate.allocation
            var highlights: [String] = []

            if allocation.blindPostsPossible == maxBlindCoverage && allocation.blindPostsPossible > 0 {
                highlights.append("Strongest blind coverage at \(allocation.blindPostsPossible)x small-blind posts.")
            }

            if allocation.totalChipsPerPlayer == minChipCount {
                highlights.append("Uses the fewest chips per player at \(allocation.totalChipsPerPlayer).")
            }

            if allocation.reserveBankTotalCents == maxReserve && maxReserve > 0 {
                highlights.append("Leaves the most value in the bank at \(allocation.reserveBankTotalString).")
            }

            if allocation.colorsOverPreferredCapCount == 0 {
                highlights.append("Keeps every chip color at 20 or fewer per player.")
            } else {
                highlights.append("Only \(allocation.colorsOverPreferredCapCount) color(s) go over the 20-chip soft cap.")
            }

            if allocation.lowChipCountPerPlayer >= 10 {
                highlights.append("Maintains healthy low-chip coverage for early betting and making change.")
            } else if allocation.lowChipCountPerPlayer >= 6 {
                highlights.append("Keeps enough low chips around for a playable opening orbit.")
            }

            let summary = recommendationSummary(
                label: labels[index],
                allocation: allocation,
                buyInCents: buyInCents,
                reservePercent: reservePercent
            )

            return AllocationRecommendation(
                label: labels[index],
                summary: summary,
                highlights: Array(highlights.prefix(3)),
                chips: candidate.chips,
                allocation: allocation
            )
        }
    }

    private static func recommendationSummary(
        label: String,
        allocation: AllocationResult,
        buyInCents: Int,
        reservePercent: Double
    ) -> String {
        switch label {
        case "Best":
            return "Best overall balance of stack feel, blind coverage, and reserve value."
        case "Better":
            if allocation.reserveBankTotalCents >= buyInCents {
                return "Balanced alternative that still protects a full rebuy in the bank."
            }
            return "Balanced alternative if you want a different mix of chip count and denomination spread."
        default:
            if reservePercent >= 0.30 {
                return "Usable fallback if you want to keep more chips behind for rebuys."
            }
            return "Usable fallback if you prefer a slightly different stack feel."
        }
    }

    private static func insertAllocation(
        _ result: AllocationResult,
        into results: inout [AllocationResult],
        limit: Int
    ) {
        results.append(result)
        results.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.blindPostsPossible != rhs.blindPostsPossible { return lhs.blindPostsPossible > rhs.blindPostsPossible }
            return lhs.totalChipsPerPlayer < rhs.totalChipsPerPlayer
        }
        if results.count > limit {
            results.removeLast(results.count - limit)
        }
    }

    private static func insertCandidate(
        _ candidate: (chips: [ChipType], allocation: AllocationResult),
        into candidates: inout [(chips: [ChipType], allocation: AllocationResult)],
        limit: Int
    ) {
        candidates.append(candidate)
        candidates.sort { lhs, rhs in
            if lhs.allocation.score != rhs.allocation.score { return lhs.allocation.score > rhs.allocation.score }
            let lhsColorPenalty = colorProgressionPenalty(for: lhs.chips)
            let rhsColorPenalty = colorProgressionPenalty(for: rhs.chips)
            if lhsColorPenalty != rhsColorPenalty { return lhsColorPenalty < rhsColorPenalty }
            if lhs.allocation.blindPostsPossible != rhs.allocation.blindPostsPossible {
                return lhs.allocation.blindPostsPossible > rhs.allocation.blindPostsPossible
            }
            return lhs.allocation.totalChipsPerPlayer < rhs.allocation.totalChipsPerPlayer
        }
        if candidates.count > limit {
            candidates.removeLast(candidates.count - limit)
        }
    }

    private static func manualAllocationSignature(_ result: AllocationResult) -> String {
        result.perPlayer
            .map { "\($0.key.denominationCents):\($0.value)" }
            .sorted()
            .joined(separator: "|")
    }

    private static func autoCandidateSignature(chips: [ChipType], allocation: AllocationResult) -> String {
        let chipSignature = chips
            .map { "\($0.colorName):\($0.denominationCents)" }
            .sorted()
            .joined(separator: "|")
        return chipSignature + "#" + manualAllocationSignature(allocation)
    }

    private static func mappedCandidateChip(_ baseChip: ChipType, using assignedChips: [ChipType]) -> ChipType {
        assignedChips.first(where: { $0.id == baseChip.id }) ?? baseChip
    }

    private static func colorProgressionPenalty(for chips: [ChipType]) -> Int {
        let normalized = chips.map { chip in
            (colorRank: preferredColorRank(for: chip.colorName), denomination: chip.denominationCents)
        }

        var penalty = 0

        for lhsIndex in normalized.indices {
            for rhsIndex in normalized.indices where rhsIndex > lhsIndex {
                let lhs = normalized[lhsIndex]
                let rhs = normalized[rhsIndex]

                if lhs.colorRank == rhs.colorRank { continue }

                if lhs.colorRank < rhs.colorRank, lhs.denomination > rhs.denomination {
                    penalty += lhs.denomination - rhs.denomination
                } else if lhs.colorRank > rhs.colorRank, lhs.denomination < rhs.denomination {
                    penalty += rhs.denomination - lhs.denomination
                }
            }
        }

        return penalty
    }

    private static func preferredColorRank(for colorName: String) -> Int {
        let normalized = colorName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return preferredColorOrder.firstIndex(of: normalized) ?? preferredColorOrder.count
    }

    private static func scoreAllocation(
        allocation: [ChipType: Int],
        buyInCents: Int,
        smallBlindCents: Int,
        bigBlindCents: Int
    ) -> Int {

        let totalChips = allocation.values.reduce(0, +)

        let exactSBChipCount = allocation
            .filter { $0.key.denominationCents == smallBlindCents }
            .map(\.value)
            .reduce(0, +)
        let usefulExactSBChipCount = min(exactSBChipCount, 8)

        let lowChipCount = allocation
            .filter { $0.key.denominationCents <= bigBlindCents }
            .map(\.value)
            .reduce(0, +)
        let usefulLowChipCount = min(lowChipCount, 16)

        let mediumChipCount = allocation
            .filter { $0.key.denominationCents <= max(bigBlindCents * 5, smallBlindCents) }
            .map(\.value)
            .reduce(0, +)
        let usefulMediumChipCount = min(mediumChipCount, 12)

        let higherValueChipCount = allocation
            .filter { $0.key.denominationCents > bigBlindCents }
            .map(\.value)
            .reduce(0, +)

        let activeColorCount = allocation.count
        let tierCount = Set(
            allocation.keys.map {
                chipTier(for: $0.denominationCents, smallBlindCents: smallBlindCents, bigBlindCents: bigBlindCents)
            }
        ).count

        let blindPostsPossible = maxBlindPostsPossible(
            smallBlindCents: smallBlindCents,
            allocation: allocation,
            cap: 10
        )

        let oversizedChipPenalty = allocation.reduce(0) { partial, item in
            let denom = item.key.denominationCents
            let count = item.value

            if denom <= bigBlindCents { return partial }

            let ratio = max(1, denom / max(bigBlindCents, 1))
            return partial + (ratio * count * 8)
        }

        let veryLargeChipPenalty = allocation.reduce(0) { partial, item in
            let denom = item.key.denominationCents
            let count = item.value

            if denom >= max(bigBlindCents * 5, 500) {
                return partial + (count * 40)
            }
            return partial
        }

        let tooFewLowChipPenalty = max(0, 8 - lowChipCount) * 180
        let tooFewSmallBlindChipPenalty = max(0, 4 - exactSBChipCount) * 220
        let tooFewMediumChipPenalty = max(0, 14 - mediumChipCount) * 65
        let noHigherValueChipPenalty = higherValueChipCount == 0 ? 700 : 0

        let preferredMaxPerColor = 20
        let tooManyOfOneColorPenalty = allocation.reduce(0) { partial, item in
            let overage = max(0, item.value - preferredMaxPerColor)
            guard overage > 0 else { return partial }

            let denom = item.key.denominationCents
            let basePenalty: Int

            if denom <= bigBlindCents {
                basePenalty = 120
            } else if denom <= max(bigBlindCents * 5, smallBlindCents) {
                basePenalty = 95
            } else {
                basePenalty = 70
            }

            let escalation = max(0, overage - 5) * basePenalty * 2
            return partial + (overage * basePenalty) + escalation
        }

        let colorDiversityBonus = min(activeColorCount, 4) * 85
        let tierDiversityBonus = tierCount * 160

        let targetChipCount = 28
        let chipCountPenalty = abs(totalChips - targetChipCount) * 8

        return
            (usefulExactSBChipCount * 180) +
            (usefulLowChipCount * 65) +
            (usefulMediumChipCount * 35) +
            (blindPostsPossible * 130) -
            noHigherValueChipPenalty -
            oversizedChipPenalty -
            veryLargeChipPenalty -
            tooFewLowChipPenalty -
            tooFewSmallBlindChipPenalty -
            tooFewMediumChipPenalty -
            tooManyOfOneColorPenalty -
            chipCountPenalty +
            colorDiversityBonus +
            tierDiversityBonus
    }

    private static func chipTier(
        for denominationCents: Int,
        smallBlindCents: Int,
        bigBlindCents: Int
    ) -> Int {
        if denominationCents <= bigBlindCents { return 0 }
        if denominationCents <= max(bigBlindCents * 5, smallBlindCents) { return 1 }
        return 2
    }

    private static func candidateDenoms(
        smallBlindCents: Int,
        bigBlindCents: Int,
        buyInCents: Int,
        colorCount: Int
    ) -> [Int] {
        var pool = Set<Int>()
        let filteredDenoms = availableDenoms.filter { $0 >= smallBlindCents }

        if filteredDenoms.contains(smallBlindCents) {
            pool.insert(smallBlindCents)
        }

        if filteredDenoms.contains(bigBlindCents) {
            pool.insert(bigBlindCents)
        }

        for denom in filteredDenoms {
            if denom <= max(buyInCents, bigBlindCents * 12) {
                pool.insert(denom)
            }
        }

        let sortedPool = Array(pool).sorted()

        if colorCount <= 6 {
            return sortedPool
        } else {
            return Array(sortedPool.prefix(min(sortedPool.count, colorCount + 4)))
        }
    }

    private static func buildFailureMessage(
        base: String,
        chips: [ChipType],
        availablePerType: [ChipType: Int],
        players: Int,
        buyInCents: Int,
        reservePercent: Double,
        smallBlindCents: Int,
        bigBlindCents: Int,
        totalAvailableValue: Int,
        totalRequiredValue: Int,
        mode: String
    ) -> String {

        var suggestions: [String] = []

        let activeChips = chips.filter { $0.quantity > 0 }
        let denominations = activeChips.map(\.denominationCents).sorted()
        let lowestDenom = denominations.first
        let lowChipTypes = activeChips.filter { $0.denominationCents <= bigBlindCents }
        let smallBlindCompatible = activeChips.filter { $0.denominationCents <= smallBlindCents }

        if totalRequiredValue > 0 && totalAvailableValue > 0 && totalAvailableValue < totalRequiredValue {
            suggestions.append("lower the reserve %, lower the buy-in, reduce players, or add more total chip value")
        }

        if let lowestDenom, lowestDenom > smallBlindCents {
            suggestions.append("add a denomination equal to the small blind (\(Money.format(cents: smallBlindCents)))")
        }

        if smallBlindCompatible.isEmpty {
            suggestions.append("include at least one chip denomination that can cover the small blind")
        }

        if lowChipTypes.isEmpty {
            suggestions.append("add more low denominations at or below the big blind for better playability")
        } else {
            let totalLowChipQty = lowChipTypes.reduce(0) { $0 + $1.quantity }
            if players > 0 && totalLowChipQty / players < 4 {
                suggestions.append("add more low-denomination chips so each player gets a more playable starting stack")
            }
        }

        if reservePercent >= 0.30 {
            suggestions.append("try a lower reserve percentage")
        }

        if !denominations.isEmpty && gcd(of: denominations) > 1 && buyInCents % gcd(of: denominations) != 0 {
            suggestions.append("choose a buy-in that matches your chip denominations more cleanly")
        }

        let validDenoms = availableDenoms.filter { $0 >= smallBlindCents }
        if mode == "auto" && activeChips.count >= validDenoms.count {
            suggestions.append("remove a chip color or widen the allowed denomination pool")
        }

        if suggestions.isEmpty {
            suggestions.append("adjust the buy-in, reserve %, or chip mix")
        }

        let topSuggestions = Array(suggestions.uniqued().prefix(3))
        let suggestionText = formattedSuggestionList(topSuggestions)

        return "\(base) Try \(suggestionText)."
    }

    private static func formattedSuggestionList(_ items: [String]) -> String {
        guard !items.isEmpty else { return "adjusting the setup" }
        if items.count == 1 { return items[0] }
        if items.count == 2 { return "\(items[0]) and \(items[1])" }

        let firstParts = items.dropLast().joined(separator: ", ")
        return "\(firstParts), and \(items.last!)"
    }

    private static func gcd(of numbers: [Int]) -> Int {
        guard var result = numbers.first else { return 1 }
        for n in numbers.dropFirst() {
            result = gcd(result, n)
        }
        return result
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            let temp = x % y
            x = y
            y = temp
        }
        return max(x, 1)
    }

    private static func emptyResult(_ message: String) -> AllocationResult {
        AllocationResult(
            perPlayer: [:],
            bankLeft: [:],
            perPlayerTotalCents: 0,
            feasible: false,
            message: message,
            score: Int.min,
            totalChipsPerPlayer: 0,
            lowChipCountPerPlayer: 0,
            blindPostsPossible: 0,
            reserveBankTotalCents: 0,
            maxSingleColorCountPerPlayer: 0,
            colorsOverPreferredCapCount: 0
        )
    }

    private static func buildSuffixMaxValue(chips: [ChipType], perPlayerMax: [Int]) -> [Int] {
        var suffix = Array(repeating: 0, count: chips.count + 1)
        guard !chips.isEmpty else { return suffix }

        for i in stride(from: chips.count - 1, through: 0, by: -1) {
            suffix[i] = suffix[i + 1] + (chips[i].denominationCents * perPlayerMax[i])
        }

        return suffix
    }

    private static func canMakeAmount(target: Int, allocation: [ChipType: Int]) -> Bool {
        if target == 0 { return true }

        var reachable = Set<Int>()
        reachable.insert(0)

        let items = allocation.sorted { $0.key.denominationCents < $1.key.denominationCents }

        for (chip, count) in items {
            guard count > 0 else { continue }

            for _ in 0..<count {
                var next = reachable
                for value in reachable {
                    let newValue = value + chip.denominationCents
                    if newValue <= target {
                        next.insert(newValue)
                    }
                }
                reachable = next

                if reachable.contains(target) {
                    return true
                }
            }
        }

        return reachable.contains(target)
    }

    private static func maxBlindPostsPossible(
        smallBlindCents: Int,
        allocation: [ChipType: Int],
        cap: Int
    ) -> Int {
        guard smallBlindCents > 0 else { return 0 }

        var maxPosts = 0
        for posts in 1...cap {
            if canMakeAmount(target: posts * smallBlindCents, allocation: allocation) {
                maxPosts = posts
            } else {
                break
            }
        }
        return maxPosts
    }

    private static func computeBankLeft(
        total: [ChipType],
        perPlayer: [ChipType: Int],
        players: Int
    ) -> [ChipType: Int] {
        var left: [ChipType: Int] = [:]

        for chip in total {
            let used = (perPlayer[chip] ?? 0) * players
            left[chip] = max(0, chip.quantity - used)
        }

        return left
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
