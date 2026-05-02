//
//  ModelsChipType.swift
//  PokerStack
//
//  Created by Alex Hakimzadeh on 2/27/26.
//

import Foundation

struct ChipType: Identifiable, Hashable, Sendable {
    let id: UUID
    var colorName: String
    var denominationCents: Int
    var quantity: Int

    init(id: UUID = UUID(), colorName: String, denominationCents: Int, quantity: Int) {
        self.id = id
        self.colorName = colorName
        self.denominationCents = denominationCents
        self.quantity = quantity
    }
}
