//
//  CashSetupStore.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 3/7/26.
//

import Foundation

struct SavedChipRow: Codable, Hashable {
    let colorName: String
    let denominationCents: Int
    let quantity: Int
}

struct SavedCashSetup: Codable {
    let players: Int
    let buyInText: String
    let reservePercent: Double
    let expectedRebuys: Int
    let bigBlindCents: Int
    let denominationModeRawValue: String
    let chips: [SavedChipRow]

    private enum CodingKeys: String, CodingKey {
        case players
        case buyInText
        case reservePercent
        case expectedRebuys
        case bigBlindCents
        case denominationModeRawValue
        case chips
    }

    init(
        players: Int,
        buyInText: String,
        reservePercent: Double,
        expectedRebuys: Int,
        bigBlindCents: Int,
        denominationModeRawValue: String,
        chips: [SavedChipRow]
    ) {
        self.players = players
        self.buyInText = buyInText
        self.reservePercent = reservePercent
        self.expectedRebuys = expectedRebuys
        self.bigBlindCents = bigBlindCents
        self.denominationModeRawValue = denominationModeRawValue
        self.chips = chips
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = try container.decode(Int.self, forKey: .players)
        buyInText = try container.decode(String.self, forKey: .buyInText)
        reservePercent = try container.decode(Double.self, forKey: .reservePercent)
        expectedRebuys = try container.decodeIfPresent(Int.self, forKey: .expectedRebuys) ?? 0
        bigBlindCents = try container.decode(Int.self, forKey: .bigBlindCents)
        denominationModeRawValue = try container.decode(String.self, forKey: .denominationModeRawValue)
        chips = try container.decode([SavedChipRow].self, forKey: .chips)
    }
}

enum CashSetupStore {
    private static let key = "PokerStack.savedCashSetup"

    static func save(_ setup: SavedCashSetup) {
        do {
            let data = try JSONEncoder().encode(setup)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to save setup: \(error)")
        }
    }

    static func load() -> SavedCashSetup? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }

        do {
            return try JSONDecoder().decode(SavedCashSetup.self, from: data)
        } catch {
            print("Failed to load setup: \(error)")
            return nil
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
