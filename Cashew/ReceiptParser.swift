//
//  ReceiptParser.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//

import Foundation

// MARK: - Parsed data structures (intermediate, before saving to SwiftData)

struct ParsedReceipt {
    var storeName: String
    var date: Date
    var total: Double
    var currency: String
    var rawText: String       // Full OCR output, shown in review for debugging
}

// MARK: - RRA QR code data

/// Structured data extracted from an RRA-compliant fiscal receipt QR code.
/// Format: `DDMMYYYY#HHMMSS#SDCID#internalHash#signature#signature`
/// Example: `08022026#185412#SDC011000805#PHGM-ASN6...#TTNK-ZKI4...#TTNK-ZKI4...`
struct RRAReceiptData {
    /// Transaction date + time (parsed from the first two QR fields).
    let date: Date
    /// The SDC device identifier (e.g. "SDC011000805") — unique per POS terminal.
    let sdcId: String
}

// MARK: - Parser

enum ReceiptParser {

    // MARK: - RRA QR code parsing

    /// Parses the payload of an RRA fiscal receipt QR code.
    /// Returns `nil` if the payload doesn't match the expected format.
    static func parseRRAQRCode(_ payload: String) -> RRAReceiptData? {
        let parts = payload.components(separatedBy: "#")
        guard parts.count >= 3 else { return nil }

        let datePart = parts[0]   // "08022026"  (DDMMYYYY)
        let timePart = parts[1]   // "185412"    (HHMMSS)
        let sdcId    = parts[2]   // "SDC011000805"

        guard datePart.count == 8, timePart.count == 6 else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "ddMMyyyyHHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = formatter.date(from: datePart + timePart) else { return nil }
        return RRAReceiptData(date: date, sdcId: sdcId)
    }

    /// Entry point. Extracts the three core fields: store name, date, total.
    /// Items are left empty — the review screen lets the user add them manually.
    static func parse(rawText: String) -> ParsedReceipt {
        let lines = rawText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return ParsedReceipt(
            storeName: extractStoreName(from: lines),
            date:      extractDate(from: lines),
            total:     extractTotal(from: lines),
            currency:  detectCurrency(in: rawText),
            rawText:   rawText
        )
    }

    // MARK: - Store name

    /// POS / system software keywords that mark lines which appear BEFORE the real store name.
    private static let systemMarkers = [
        "version", "devnet", "cis version", "pos version", "software",
        "www.", ".com", ".net", ".org", "http", "fax:", "powered by",
    ]

    private static func extractStoreName(from lines: [String]) -> String {
        // Find the first system-marker line so we skip all header garbage before it.
        let systemIdx = lines.firstIndex { line in
            let lower = line.lowercased()
            return systemMarkers.contains { lower.contains($0) }
        }

        // Search after the system block (or from the top if none found).
        let start = (systemIdx ?? -1) + 1
        for line in lines[start...].prefix(10) {
            if isValidStoreName(line) {
                return line.trimmingCharacters(in: .whitespaces)
            }
        }
        return "Unknown Store"
    }

    private static func isValidStoreName(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.count >= 4, t.count <= 60 else { return false }
        guard !isNumberOnly(t)            else { return false }
        guard !isDateLine(t)              else { return false }
        guard !isTimeLine(t)              else { return false }
        // Need at least 4 real letters (rules out "/E/", "TIN", codes, etc.)
        guard t.filter({ $0.isLetter }).count >= 4 else { return false }
        // Looks like a phone number → skip
        if t.range(of: #"^\+?\d[\d\s\-]{7,}"#, options: .regularExpression) != nil { return false }
        let lower = t.lowercased()
        for marker in systemMarkers where lower.contains(marker) { return false }
        if lower.contains("tin:") || lower.contains("tin ") ||
           lower.contains("client")                            { return false }
        return true
    }

    // MARK: - Date

    /// Public entry point: extracts the best date found in `rawText`.
    /// Used by `ReceiptScannerView` when Foundation Models handles the other fields.
    static func extractDate(fromRawText rawText: String) -> Date {
        let lines = rawText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return extractDate(from: lines)
    }

    private static func extractDate(from lines: [String]) -> Date {
        // Order matters: try most-specific patterns first.
        let patterns: [(String, String)] = [
            (#"\d{4}-\d{2}-\d{2}"#, "yyyy-MM-dd"),   // ISO 8601 — common on RRA receipts
            (#"\d{2}/\d{2}/\d{4}"#, "dd/MM/yyyy"),
            (#"\d{2}-\d{2}-\d{4}"#, "dd-MM-yyyy"),
            (#"\d{2}/\d{2}/\d{2}"#,  "dd/MM/yy"),
            (#"\d{2}\.\d{2}\.\d{4}"#, "dd.MM.yyyy"),
        ]
        for line in lines {
            for (pattern, format) in patterns {
                if let range = line.range(of: pattern, options: .regularExpression),
                   let date  = parseDate(String(line[range]), format: format) {
                    return date
                }
            }
        }
        return Date()
    }

    private static func parseDate(_ s: String, format: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = format
        return f.date(from: s)
    }

    // MARK: - Total

    /// Words that, when they appear right after "TOTAL", mean the line is a
    /// tax/breakdown line — NOT the primary total we want.
    private static let totalModifiers = [
        "TAX", "A-EX", "B-18", "HT", "TTC", "TVA", "NET"
    ]

    private static func extractTotal(from lines: [String]) -> Double {

        // ── Strategy 1: "TOTAL" at the start of a line WITH its amount on the same line ──
        //
        // Matches:   "TOTAL  5,400.00"      → 5400
        //            "TOTAL: 5,400.00"      → 5400
        //            "TOTAL AMOUNT 5,400"   → 5400
        // Skips:     "TOTAL TAX  823.73"    (TAX is a modifier)
        //            "TOTAL B-18%  5,400"   (B-18 is a modifier)
        //            "TOTAL A-EX  0.00"     (A-EX is a modifier)
        //            "TOTAL" alone (no number on the line)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let upper   = trimmed.uppercased()
            guard upper.hasPrefix("TOTAL") else { continue }

            // Check what immediately follows "TOTAL"
            let tail = String(upper.dropFirst(5)).trimmingCharacters(in: .whitespaces)

            // Skip breakdown lines where the word after TOTAL is a known modifier
            if totalModifiers.contains(where: { tail.hasPrefix($0) }) { continue }

            // There must be a number somewhere on this line
            if let amount = extractLastAmount(from: trimmed), amount > 0 {
                return amount
            }
        }

        // ── Strategy 2: two-column layout — "TOTAL" alone on its own line ──────────────
        //
        // Some POS systems (e.g. RRA-compliant receipts) print the totals section as a
        // two-column table. Vision OCR reads the entire left column first (labels), then
        // the entire right column (values). So "TOTAL" and "5,400.00" end up many lines apart.
        //
        // Since TOTAL is always the first label in that block, its value is the first
        // pure-number line we find after all the label lines.

        if let totalLineIdx = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces).uppercased() == "TOTAL"
        }) {
            for line in lines[(totalLineIdx + 1)...] {
                let t = line.trimmingCharacters(in: .whitespaces)
                // Pure-number lines are the value block
                if isNumberOnly(t), let amount = extractLastAmount(from: t), amount > 0 {
                    return amount
                }
                // Non-label, non-number line → values block is over, stop
                let upper = t.uppercased()
                let isLabelLine = upper.hasPrefix("TOTAL") || upper == "CASH" ||
                                  upper == "ITEMS NUMBER" || upper.contains("TAX") ||
                                  upper.contains("CASHIER") || upper.contains("RCVD") ||
                                  upper.contains("CHAN") || upper.contains("PAY")
                if !isLabelLine && !isNumberOnly(t) { break }
            }
        }

        return 0  // Nothing found — user fills in manually in the review screen
    }

    // MARK: - Currency

    private static func detectCurrency(in text: String) -> String {
        if text.contains("RWF") || text.contains("Frw") || text.contains("FRW") { return "RWF" }
        if text.contains("KES") || text.contains("Ksh")                         { return "KES" }
        if text.contains("UGX")                                                  { return "UGX" }
        if text.contains("TZS")                                                  { return "TZS" }
        if text.contains("USD") || text.contains("$")                            { return "USD" }
        if text.contains("EUR") || text.contains("€")                            { return "EUR" }
        if text.contains("GBP") || text.contains("£")                            { return "GBP" }
        return "RWF"
    }

    // MARK: - Shared helpers

    /// Extracts the rightmost price-like number from a line.
    /// Also normalises OCR decimal-space artifacts: "5,400. 00" → "5,400.00".
    static func extractLastAmount(from line: String) -> Double? {
        let normalised = line.replacingOccurrences(
            of: #"(\d)\.\s+(\d)"#, with: "$1.$2", options: .regularExpression
        )
        let pattern = #"[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{1,2})?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = NSRange(normalised.startIndex..., in: normalised)
        guard let last = regex.matches(in: normalised, range: ns).last,
              let range = Range(last.range, in: normalised)
        else { return nil }
        return Double(String(normalised[range]).replacingOccurrences(of: ",", with: ""))
    }

    private static func isTimeLine(_ s: String) -> Bool {
        s.range(of: #"\d{1,2}:\d{2}(:\d{2})?"#, options: .regularExpression) != nil
            && s.filter({ $0.isLetter }).count < 4
    }

    private static func isDateLine(_ s: String) -> Bool {
        s.range(of: #"\d{2}[/\-.]\d{2}[/\-.]\d{2,4}"#, options: .regularExpression) != nil ||
        s.range(of: #"\d{4}-\d{2}-\d{2}"#,             options: .regularExpression) != nil
    }

    private static func isNumberOnly(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        return !t.isEmpty && t.allSatisfy { $0.isNumber || $0 == "." || $0 == "," || $0 == " " }
    }

    private static func isTimeString(_ s: String) -> Bool {
        s.range(of: #"^\d{1,2}:\d{2}"#, options: .regularExpression) != nil
    }
}
