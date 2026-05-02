//
//  AutoDenominationAssigner.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 3/6/26.
//

import Foundation

enum AutoDenominationAssigner {

    static let availableDenoms: [Int] = [
        10, 25, 50, 100, 200, 500, 1000, 2500, 5000, 10000, 50000, 100000
    ]

    static func assignDenominations(
        to chips: [ChipType],
        bigBlindCents: Int,
        smallBlindCents: Int,
        buyInCents: Int,
        players: Int,
        reservePercent: Double
    ) -> [ChipType] {

        guard !chips.isEmpty else { return chips }

        // Sort chip colors by quantity descending.
        // Most plentiful colors get the most useful denominations.
        let sortedByQty = chips.sorted { $0.quantity > $1.quantity }

        // Determine a smart pool of denominations based on blind level + buy-in size.
        let recommended = recommendedDenominations(
            buyInCents: buyInCents,
            bigBlindCents: bigBlindCents,
            smallBlindCents: smallBlindCents,
            colorCount: chips.count
        )

        var assigned: [ChipType] = []

        for (index, chip) in sortedByQty.enumerated() {
            var updated = chip
            let denom = index < recommended.count
                ? recommended[index]
                : recommended.last ?? 100
            updated.denominationCents = denom
            assigned.append(updated)
        }

        // Put back in original order
        var map: [UUID: ChipType] = [:]
        for chip in assigned {
            map[chip.id] = chip
        }

        return chips.compactMap { map[$0.id] }
    }

    private static func recommendedDenominations(
        buyInCents: Int,
        bigBlindCents: Int,
        smallBlindCents: Int,
        colorCount: Int
    ) -> [Int] {

        // Start with smallest practical denomination.
        var base: [Int] = []
        base = [10, 25, 50, 100, 500, 2500, 10000, 50000]
        if smallBlindCents == 25 {
            base = [25, 50, 100, 500, 2500, 10000, 50000]
        }
        if smallBlindCents == 50 {
            base = [50, 100, 500, 2500, 10000, 50000]
        }
        if smallBlindCents == 100 {
            base = [100, 500, 2500, 10000, 50000]
        }
        if smallBlindCents == 200 {
            base = [100, 500, 2500, 10000, 50000]
        }
        if smallBlindCents == 500 {
            base = [500, 2500, 10000, 50000, 100000]
        }
        if smallBlindCents == 1000 {
            base = [10000, 50000, 100000, 500000]
        }

        // Make sure values are in supported list only
        base = base.filter { availableDenoms.contains($0) }

        // Trim or extend to fit number of colors
        if colorCount <= base.count {
            return Array(base.prefix(colorCount))
        } else {
            var expanded = base
            for denom in availableDenoms.reversed() {
                if !expanded.contains(denom) {
                    expanded.append(denom)
                }
                if expanded.count == colorCount { break }
            }
            return expanded
        }
    }
}
