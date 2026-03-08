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
    let bigBlindCents: Int
    let denominationModeRawValue: String
    let chips: [SavedChipRow]
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
