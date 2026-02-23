//
//  FoundationModelService.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//
//  Uses Apple Foundation Models (iOS 18.1+, Apple Intelligence devices) to extract
//  structured receipt data from raw OCR text.  Falls back to ReceiptParser on
//  devices that don't support the on-device LLM (e.g. iPhone 12).
//

import Foundation
import FoundationModels

// MARK: - Structured output type

/// The three core fields we extract from a receipt.
/// Decorated with @Generable so the on-device LLM returns a typed Swift value
/// rather than free-form text.
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
}

// MARK: - Service

/// Wrapper around `LanguageModelSession` for receipt data extraction.
@available(iOS 18.1, *)
enum FoundationModelService {

    // MARK: - Public API

    /// Tries to extract store name, total, and currency from raw OCR text using the
    /// on-device Apple Foundation Model.
    ///
    /// - Returns: `ExtractedReceiptData` on success, `nil` if the model is unavailable
    ///   or if extraction throws (both are normal — the caller falls back to regex).
    static func extractReceiptData(from rawText: String) async -> ExtractedReceiptData? {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            print("Show your intelligence UI.")
        case .unavailable(.deviceNotEligible):
            print("Show an alternative UI.")
        case .unavailable(.appleIntelligenceNotEnabled):
                    print("Ask the person to turn on Apple Intelligence.")
        case .unavailable(.modelNotReady):
                            print("The model isn't ready because it's downloading or because of other system reasons.")
        case .unavailable(let other):
            print("The model is unavailable for an unknown reason.")
        }
        guard SystemLanguageModel.default.isAvailable else {
            print("[Cashew] Foundation Models: not available on this device.")
            return nil
        }

        let session = LanguageModelSession()
        let prompt  = buildPrompt(for: rawText)

        do {
            let result = try await session.respond(to: prompt, generating: ExtractedReceiptData.self)
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
        of a supermarket receipt. Extract the three fields described in the response schema.

        Notes on this OCR output:
        • Numbers may have stray spaces near the decimal (e.g. "5,400. 00" means 5400.00).
        • Lines are separated by newlines; columns are not always aligned.
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
