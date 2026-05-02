//
//  TournamentSetupStore.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 3/25/26.
//

import Foundation

struct SavedTournamentSetup: Codable {
    let players: Int
    let buyInText: String
    let plannedLateRegistrations: Int
    let plannedRebuys: Int
    let plannedAddOns: Int
    let addOnValueTexts: [String]
    let blindSpeedRawValue: String
    let denominationModeRawValue: String
    let chips: [SavedChipRow]

    private enum CodingKeys: String, CodingKey {
        case players
        case buyInText
        case plannedLateRegistrations
        case plannedRebuys
        case plannedAddOns
        case addOnValueTexts
        case blindSpeedRawValue
        case denominationModeRawValue
        case chips
    }

    init(
        players: Int,
        buyInText: String,
        plannedLateRegistrations: Int,
        plannedRebuys: Int,
        plannedAddOns: Int,
        addOnValueTexts: [String],
        blindSpeedRawValue: String,
        denominationModeRawValue: String,
        chips: [SavedChipRow]
    ) {
        self.players = players
        self.buyInText = buyInText
        self.plannedLateRegistrations = plannedLateRegistrations
        self.plannedRebuys = plannedRebuys
        self.plannedAddOns = plannedAddOns
        self.addOnValueTexts = addOnValueTexts
        self.blindSpeedRawValue = blindSpeedRawValue
        self.denominationModeRawValue = denominationModeRawValue
        self.chips = chips
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = try container.decode(Int.self, forKey: .players)
        buyInText = try container.decode(String.self, forKey: .buyInText)
        plannedLateRegistrations = try container.decode(Int.self, forKey: .plannedLateRegistrations)
        plannedRebuys = try container.decode(Int.self, forKey: .plannedRebuys)
        plannedAddOns = try container.decode(Int.self, forKey: .plannedAddOns)
        addOnValueTexts = try container.decodeIfPresent([String].self, forKey: .addOnValueTexts) ?? ["10", "20"]
        blindSpeedRawValue = try container.decode(String.self, forKey: .blindSpeedRawValue)
        denominationModeRawValue = try container.decode(String.self, forKey: .denominationModeRawValue)
        chips = try container.decode([SavedChipRow].self, forKey: .chips)
    }
}

enum TournamentSetupStore {
    private static let key = "PokerStack.savedTournamentSetup"

    static func save(_ setup: SavedTournamentSetup) {
        do {
            let data = try JSONEncoder().encode(setup)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to save tournament setup: \(error)")
        }
    }

    static func load() -> SavedTournamentSetup? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }

        do {
            return try JSONDecoder().decode(SavedTournamentSetup.self, from: data)
        } catch {
            print("Failed to load tournament setup: \(error)")
            return nil
        }
    }
}
