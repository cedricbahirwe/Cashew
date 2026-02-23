//
//  Receipt.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//

import Foundation
import SwiftData

// MARK: - Processing status

/// Whether the receipt has been fully extracted or is waiting for server-side processing.
enum ReceiptStatus: String, Codable {
    /// All fields (store, date, total, items) have been extracted — either by Apple
    /// Intelligence on-device or by the future API.
    case complete

    /// The image has been captured but extraction hasn't happened yet.
    /// These receipts will be sent to the backend API when connectivity allows.
    case pending
}

// MARK: - Model

@Model
final class Receipt {
    var storeName: String
    var receiptDate: Date
    var scannedAt: Date
    var totalAmount: Double
    var currency: String
    var imageData: Data?
    var rawText: String
    var statusRaw: String                               // stores ReceiptStatus.rawValue
    @Relationship(deleteRule: .cascade) var items: [ReceiptItem]

    var status: ReceiptStatus {
        get { ReceiptStatus(rawValue: statusRaw) ?? .complete }
        set { statusRaw = newValue.rawValue }
    }

    var isPending: Bool { status == .pending }

    init(
        storeName: String = "",
        receiptDate: Date = Date(),
        totalAmount: Double = 0.0,
        currency: String = "RWF",
        imageData: Data? = nil,
        rawText: String = "",
        items: [ReceiptItem] = [],
        status: ReceiptStatus = .complete
    ) {
        self.storeName    = storeName
        self.receiptDate  = receiptDate
        self.scannedAt    = Date()
        self.totalAmount  = totalAmount
        self.currency     = currency
        self.imageData    = imageData
        self.rawText      = rawText
        self.statusRaw    = status.rawValue
        self.items        = items
    }

    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let formatted = formatter.string(from: NSNumber(value: totalAmount)) ?? "\(Int(totalAmount))"
        return "\(currency) \(formatted)"
    }
}
