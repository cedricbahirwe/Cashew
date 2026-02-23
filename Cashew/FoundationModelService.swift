//
//  FoundationModelService.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//
//  Uses Apple Foundation Models (iOS 18.1+, Apple Intelligence devices) to extract
//  structured receipt data from raw OCR text.
//
//  For devices without Apple Intelligence the caller saves the receipt as `.pending`
//  and defers extraction to a future API.
//

import Foundation
import FoundationModels

// MARK: - Structured output types

/// A single line item extracted from a receipt.
@available(iOS 18.1, *)
@Generable
struct ExtractedItem {
    @Guide(description: """
        The product name as printed on the receipt.
        Clean up obvious OCR noise but keep the original wording.
        Examples: "Milk 1L", "Bread White 600g", "Coca Cola 500ml".
        """)
    var name: String

    @Guide(description: """
        Quantity purchased for this line item.
        Usually shown as a number before or after the product name, or on a separate line.
        Default to 1 if not explicitly shown.
        """)
    var quantity: Int

    @Guide(description: """
        Price per single unit of the product.
        Often labeled "Unit Price" or shown in a second column.
        Return 0 if not shown.
        """)
    var unitPrice: Double

    @Guide(description: """
        Total price for this line item (quantity × unit price).
        This is the rightmost price column.
        Strip commas and spaces (e.g. "1,500.00" → 1500.0).
        """)
    var totalPrice: Double
}

/// All structured data we extract from a receipt in a single LLM call.
@available(iOS 18.1, *)
@Generable
struct ExtractedReceiptData {
    /// Name of the store or business shown in the receipt header.
    @Guide(description: """
        The name of the store or business printed on the receipt.
        It usually appears in the first few lines as a heading.
        Examples: "Simba Supermarket", "Nakumatt", "Carrefour", "Quick Mart".
        Return "Unknown Store" if the name cannot be determined.
        """)
    var storeName: String

    /// Grand total amount paid, as a plain number (no currency symbols or commas).
    @Guide(description: """
        The final total amount paid on the receipt.
        Look for a line that starts with the word TOTAL (by itself, not "TOTAL TAX",
        "TOTAL B-18%", "TOTAL A-EX", "TOTAL HT" — those are subtotals, ignore them).
        Strip commas and spaces from the number (e.g. "5,400.00" → 5400.0).
        Return 0 if not found.
        """)
    var totalAmount: Double

    /// ISO 4217 currency code detected on the receipt.
    @Guide(description: """
        The currency used on the receipt.
        Look for currency codes or symbols near amounts:
          RWF or FRW or Frw → "RWF"
          KES or Ksh        → "KES"
          UGX               → "UGX"
          TZS               → "TZS"
          USD or $          → "USD"
          EUR or €          → "EUR"
          GBP or £          → "GBP"
        Default to "RWF" when no currency indicator is found (most receipts are Rwandan).
        """)
    var currency: String

    /// All line items purchased on this receipt.
    @Guide(description: """
        Every product line item on the receipt.
        Important: OCR from POS receipts often reads the entire left column (item names) then
        the entire right column (prices), so names and prices may be many lines apart.
        Pair them intelligently based on position and context.
        Exclude header, subtotal, tax, and footer lines.
        Return an empty array if no items can be reliably identified.
        """)
    var items: [ExtractedItem]
}

// MARK: - Service

/// Wrapper around `LanguageModelSession` for receipt data extraction.
/// Only available on iOS 18.1+ devices with Apple Intelligence enabled.
@available(iOS 18.1, *)
enum FoundationModelService {

    // MARK: - Availability check

    /// Returns whether the on-device model is ready to use.
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    // MARK: - Public API

    /// Extracts all receipt fields from raw OCR text using the on-device language model.
    ///
    /// - Returns: `ExtractedReceiptData` on success, `nil` if unavailable or extraction fails.
    static func extractReceiptData(from rawText: String) async -> ExtractedReceiptData? {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break   // proceed below
        case .unavailable(.deviceNotEligible):
            print("[Cashew] Foundation Models: device not eligible for Apple Intelligence.")
            return nil
        case .unavailable(.appleIntelligenceNotEnabled):
            print("[Cashew] Foundation Models: Apple Intelligence not enabled by user.")
            return nil
        case .unavailable(.modelNotReady):
            print("[Cashew] Foundation Models: model not ready (still downloading?).")
            return nil
        case .unavailable(let other):
            print("[Cashew] Foundation Models: unavailable — \(other).")
            return nil
        }

        let session = LanguageModelSession()

        do {
            let result = try await session.respond(
                to: buildPrompt(for: rawText),
                generating: ExtractedReceiptData.self
            )
            return result.content
        } catch {
            print("[Cashew] Foundation Models extraction error: \(error)")
            return nil
        }
    }

    // MARK: - Prompt

    private static func buildPrompt(for rawText: String) -> String {
        """
        You are a receipt-data extractor. The text below is the raw output from an OCR scan \
        of a supermarket receipt. Extract all fields described in the response schema.

        Notes on this OCR output:
        • Numbers may have stray spaces near the decimal (e.g. "5,400. 00" means 5400.00).
        • Lines are separated by newlines; columns are not always aligned.
        • POS receipts often put all item names first, then all prices — pair them by order.
        • The receipt may start with POS system header garbage before the actual store name.
        • Ignore lines like "TOTAL TAX", "TOTAL B-18%", "TOTAL A-EX" — those are subtotals.
        • Most receipts are Rwandan; default to RWF if no currency code is found.

        Receipt OCR text:
        ---
        \(rawText)
        ---
        """
    }
}
