//
//  ChipSetStore.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 3/7/26.
//

import Foundation

struct SavedNamedChipSet: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let chips: [SavedChipRow]
    let createdAt: Date

    init(id: UUID = UUID(), name: String, chips: [SavedChipRow], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.chips = chips
        self.createdAt = createdAt
    }
}

enum ChipSetStore {
    private static let key = "PokerStack.savedChipSets"

    static func loadAll() -> [SavedNamedChipSet] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }

        do {
            let decoded = try JSONDecoder().decode([SavedNamedChipSet].self, from: data)
            return decoded.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("Failed to load chip sets: \(error)")
            return []
        }
    }

    static func saveAll(_ chipSets: [SavedNamedChipSet]) {
        do {
            let data = try JSONEncoder().encode(chipSets)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to save chip sets: \(error)")
        }
    }

    static func save(name: String, chips: [SavedChipRow]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var existing = loadAll()

        if let index = existing.firstIndex(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            existing[index] = SavedNamedChipSet(
                id: existing[index].id,
                name: trimmed,
                chips: chips,
                createdAt: Date()
            )
        } else {
            existing.insert(SavedNamedChipSet(name: trimmed, chips: chips), at: 0)
        }

        saveAll(existing)
    }

    static func delete(id: UUID) {
        var existing = loadAll()
        existing.removeAll { $0.id == id }
        saveAll(existing)
    }
}
