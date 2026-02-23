//
//  Receipt.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//

import Foundation
import SwiftData

@Model
final class Receipt {
    var storeName: String
    var receiptDate: Date
    var scannedAt: Date
    var totalAmount: Double
    var currency: String
    var imageData: Data?
    var rawText: String
    @Relationship(deleteRule: .cascade) var items: [ReceiptItem]

    init(
        storeName: String = "Unknown Store",
        receiptDate: Date = Date(),
        totalAmount: Double = 0.0,
        currency: String = "RWF",
        imageData: Data? = nil,
        rawText: String = "",
        items: [ReceiptItem] = []
    ) {
        self.storeName = storeName
        self.receiptDate = receiptDate
        self.scannedAt = Date()
        self.totalAmount = totalAmount
        self.currency = currency
        self.imageData = imageData
        self.rawText = rawText
        self.items = items
    }

    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let formatted = formatter.string(from: NSNumber(value: totalAmount)) ?? "\(Int(totalAmount))"
        return "\(currency) \(formatted)"
    }
}
