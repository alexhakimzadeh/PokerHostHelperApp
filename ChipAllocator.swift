//
//  LogicChipAllocator.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 2/27/26.
//

import Foundation

struct AllocationResult {
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

    var perPlayerTotalString: String { Money.format(cents: perPlayerTotalCents) }
    var reserveBankTotalString: String { Money.format(cents: reserveBankTotalCents) }
}

struct AutoOptimizationResult: Sendable {
    var chips: [ChipType]
    var allocation: AllocationResult
}

enum ChipAllocator: Sendable {

    static let availableDenoms: [Int] = [
        10, 25, 50, 100, 200, 500, 1000, 2500, 5000, 10000, 50000
    ]

    // MARK: - Manual Allocation

    static func allocate(
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
        guard totalAvailableValue >= totalRequired else {
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

        let perPlayerMax = sorted.map { availablePerType[$0, default: 0] / players }
        let suffixMaxValue = buildSuffixMaxValue(chips: sorted, perPlayerMax: perPlayerMax)

        var bestAllocation: [ChipType: Int]? = nil
        var bestScore = Int.min
        var currentCounts = Array(repeating: 0, count: sorted.count)

        func dfs(_ index: Int, _ remaining: Int) {
            if remaining < 0 { return }

            if index == sorted.count {
                if remaining == 0 {
                    let allocation = Dictionary(
                        uniqueKeysWithValues: zip(sorted, currentCounts).filter { $0.1 > 0 }
                    )

                    guard canMakeAmount(target: smallBlindCents, allocation: allocation) else {
                        return
                    }

                    let score = scoreAllocation(
                        allocation: allocation,
                        buyInCents: buyInCents,
                        smallBlindCents: smallBlindCents,
                        bigBlindCents: bigBlindCents
                    )

                    if score > bestScore {
                        bestScore = score
                        bestAllocation = allocation
                    }
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

        guard let bestAllocation else {
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

        let totalPerPlayer = bestAllocation.reduce(0) { $0 + ($1.key.denominationCents * $1.value) }
        let bankLeft = computeBankLeft(total: chips, perPlayer: bestAllocation, players: players)

        let totalChips = bestAllocation.values.reduce(0, +)
        let lowChipCount = bestAllocation
            .filter { $0.key.denominationCents <= bigBlindCents }
            .map(\.value)
            .reduce(0, +)

        let blindPosts = maxBlindPostsPossible(
            smallBlindCents: smallBlindCents,
            allocation: bestAllocation,
            cap: 12
        )

        let reserveBankTotal = bankLeft.reduce(0) { partial, item in
            partial + (item.key.denominationCents * item.value)
        }

        return AllocationResult(
            perPlayer: bestAllocation,
            bankLeft: bankLeft,
            perPlayerTotalCents: totalPerPlayer,
            feasible: true,
            message: "Optimal allocation found.",
            score: bestScore,
            totalChipsPerPlayer: totalChips,
            lowChipCountPerPlayer: lowChipCount,
            blindPostsPossible: blindPosts,
            reserveBankTotalCents: reserveBankTotal
        )
    }

    // MARK: - Auto Optimization

    static func optimizeAuto(
        chips: [ChipType],
        players: Int,
        buyInCents: Int,
        reservePercent: Double,
        smallBlindCents: Int,
        bigBlindCents: Int
    ) -> AutoOptimizationResult {

        let activeChips = chips.filter { $0.quantity > 0 }
        guard !activeChips.isEmpty else {
            return AutoOptimizationResult(
                chips: chips,
                allocation: emptyResult("Add at least one chip color with a quantity greater than 0.")
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
            return AutoOptimizationResult(chips: chips, allocation: emptyResult(msg))
        }

        let originalOrder = activeChips
        var bestChips: [ChipType]? = nil
        var bestAllocation: AllocationResult? = nil
        var currentAssignment: [Int] = []
        var used = Set<Int>()

        func backtrack() {
            if currentAssignment.count == originalOrder.count {
                var assignedChips: [ChipType] = []

                for (idx, chip) in originalOrder.enumerated() {
                    var updated = chip
                    updated.denominationCents = currentAssignment[idx]
                    assignedChips.append(updated)
                }

                guard assignedChips.allSatisfy({ $0.denominationCents >= smallBlindCents }) else {
                    return
                }

                let allocation = allocate(
                    chips: assignedChips,
                    players: players,
                    buyInCents: buyInCents,
                    reservePercent: reservePercent,
                    smallBlindCents: smallBlindCents,
                    bigBlindCents: bigBlindCents
                )

                if allocation.feasible {
                    if bestAllocation == nil || allocation.score > bestAllocation!.score {
                        bestAllocation = allocation
                        bestChips = assignedChips
                    }
                }

                return
            }

            for denom in pool {
                if used.contains(denom) { continue }
                used.insert(denom)
                currentAssignment.append(denom)
                backtrack()
                currentAssignment.removeLast()
                used.remove(denom)
            }
        }

        backtrack()

        if let bestChips, let bestAllocation {
            var mapped: [UUID: ChipType] = [:]
            for chip in bestChips {
                mapped[chip.id] = chip
            }

            let updatedAll = chips.map { mapped[$0.id] ?? $0 }
            return AutoOptimizationResult(chips: updatedAll, allocation: bestAllocation)
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
        return AutoOptimizationResult(
            chips: chips,
            allocation: emptyResult(msg)
        )
    }

    // MARK: - Scoring

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

        let lowChipCount = allocation
            .filter { $0.key.denominationCents <= bigBlindCents }
            .map(\.value)
            .reduce(0, +)

        let blindPostsPossible = maxBlindPostsPossible(
            smallBlindCents: smallBlindCents,
            allocation: allocation,
            cap: 8
        )

        let chipCountPenalty = abs(totalChips - 25) * 4

        let tooManyHugeChipsPenalty = allocation
            .filter { $0.key.denominationCents > max(bigBlindCents * 10, 1000) }
            .map(\.value)
            .reduce(0, +) * 3

        return
            (exactSBChipCount * 250) +
            (blindPostsPossible * 120) +
            (min(lowChipCount, 14) * 30) -
            chipCountPenalty -
            tooManyHugeChipsPenalty
    }

    // MARK: - Auto Candidate Denoms

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
            if denom <= max(buyInCents, bigBlindCents * 20) {
                pool.insert(denom)
            }
        }

        let sortedPool = Array(pool).sorted()

        if colorCount <= 6 {
            return sortedPool
        } else {
            return Array(sortedPool.prefix(min(sortedPool.count, colorCount + 3)))
        }
    }

    // MARK: - Dynamic Failure Messaging

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
            if players > 0 && totalLowChipQty / players < 3 {
                suggestions.append("add more low-denomination chips so each player gets a more playable starting stack")
            }
        }

        if reservePercent >= 0.30 {
            suggestions.append("try a lower reserve percentage")
        }

        if !denominations.isEmpty && gcd(of: denominations) > 1 && buyInCents % gcd(of: denominations) != 0 {
            suggestions.append("choose a buy-in that matches your chip denominations more cleanly")
        }

        if mode == "auto" && activeChips.count >= availableDenoms.filter({ $0 >= smallBlindCents }).count {
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

    // MARK: - Helpers

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
            reserveBankTotalCents: 0
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
