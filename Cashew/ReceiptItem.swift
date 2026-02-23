//
//  ReceiptItem.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//

import Foundation
import SwiftData

@Model
final class ReceiptItem {
    var name: String
    var quantity: Int
    var unitPrice: Double
    var totalPrice: Double

    init(
        name: String,
        quantity: Int = 1,
        unitPrice: Double = 0.0,
        totalPrice: Double = 0.0
    ) {
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
    }
}
