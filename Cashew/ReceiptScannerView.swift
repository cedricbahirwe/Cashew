//
//  ReceiptScannerView.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//

import SwiftUI
import VisionKit
import PhotosUI
import UIKit
import SwiftData

// MARK: - Main scanner flow

struct ReceiptScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var stage: Stage = .scanning

    enum Stage {
        case scanning
        case processing(String)       // message shown while working
        case reviewing(UIImage, ParsedReceipt)
        case error(String)
    }

    var body: some View {
        switch stage {

        // ── Scanning ─────────────────────────────────────────────────────────
        case .scanning:
            if VNDocumentCameraViewController.isSupported {
                DocumentScannerWrapper {
                    handleScan($0)
                } onCancel: {
                    dismiss()
                }
                .ignoresSafeArea()
            } else {
                // Simulator / devices without a camera → photo library picker
                SimulatorPickerView { image in
                    handleImage(image)
                } onCancel: {
                    dismiss()
                }
            }

        // ── Processing ───────────────────────────────────────────────────────
        case .processing(let message):
            ProcessingView(message: message)

        // ── Review ───────────────────────────────────────────────────────────
        case .reviewing(let image, let parsed):
            ReceiptReviewView(image: image, parsed: parsed) { storeName, date, items, total, currency in
                saveReceipt(
                    image: image,
                    storeName: storeName,
                    date: date,
                    items: items,
                    total: total,
                    currency: currency,
                    rawText: parsed.rawText
                )
            } onCancel: {
                dismiss()
            }

        // ── Error ────────────────────────────────────────────────────────────
        case .error(let message):
            ScanErrorView(message: message, onDismiss: { dismiss() })
        }
    }

    // MARK: - Scan handlers

    /// Called by DocumentScannerWrapper after a successful camera scan.
    private func handleScan(_ scan: VNDocumentCameraScan) {
        handleImage(scan.imageOfPage(at: 0))
    }

    /// Shared pipeline for both camera scans and photo-picker selections.
    private func handleImage(_ image: UIImage) {
        stage = .processing("Scanning receipt…")

        Task {
            // Step 1 – OCR + QR detection in parallel
            async let ocrTask = VisionService.recognizeText(from: image)
            async let qrTask  = VisionService.detectQRCode(from: image)

            let rawText  = await ocrTask
            let qrPayload = await qrTask

            // Step 2 – Try Foundation Models (iOS 18.1+, Apple Intelligence)
            //           Falls back to regex parser on older/incompatible devices.
            var parsed = await extractReceiptData(from: rawText)

            // Step 3 – QR date override: the RRA fiscal QR encodes the exact
            //           transaction date/time, far more reliable than OCR.
            if let payload = qrPayload,
               let rraData = ReceiptParser.parseRRAQRCode(payload) {
                parsed.date = rraData.date
            }

            await MainActor.run {
                stage = .reviewing(image, parsed)
            }
        }
    }

    // MARK: - Extraction strategy

    /// Tries Foundation Models first; falls back to the regex parser.
    private func extractReceiptData(from rawText: String) async -> ParsedReceipt {

        // Foundation Models: on-device LLM — iOS 18.1+, Apple Intelligence devices only.
        if #available(iOS 18.1, *) {
            await MainActor.run { stage = .processing("Analysing with Apple Intelligence…") }

            if let extracted = await FoundationModelService.extractReceiptData(from: rawText) {
                return ParsedReceipt(
                    storeName: extracted.storeName,
                    date:      ReceiptParser.extractDate(fromRawText: rawText),   // regex date (QR may override later)
                    items:     [],
                    total:     extracted.totalAmount,
                    currency:  extracted.currency,
                    rawText:   rawText
                )
            }
        }

        // Fallback: regex-based parser (always works, even on iPhone 12).
        await MainActor.run { stage = .processing("Extracting receipt data…") }
        return ReceiptParser.parse(rawText: rawText)
    }

    // MARK: - Save

    private func saveReceipt(
        image: UIImage,
        storeName: String,
        date: Date,
        items: [ParsedItem],
        total: Double,
        currency: String,
        rawText: String = ""
    ) {
        let imageData    = image.jpegData(compressionQuality: 0.75)
        let receiptItems = items.map {
            ReceiptItem(
                name:       $0.name,
                quantity:   $0.quantity,
                unitPrice:  $0.unitPrice,
                totalPrice: $0.totalPrice
            )
        }
        let receipt = Receipt(
            storeName:    storeName,
            receiptDate:  date,
            totalAmount:  total,
            currency:     currency,
            imageData:    imageData,
            rawText:      rawText,
            items:        receiptItems
        )
        modelContext.insert(receipt)
        dismiss()
    }
}

// MARK: - Simulator photo picker

/// Shown when `VNDocumentCameraViewController` is unavailable (Simulator or iPad without camera).
/// Lets the user pick a receipt photo from their library for testing.
private struct SimulatorPickerView: View {
    let onImageSelected: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.green.gradient)

                VStack(spacing: 8) {
                    Text("Camera Unavailable")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Pick a receipt photo from your library to test the app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                PhotosPicker(
                    selection: $pickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(isLoading ? "Loading…" : "Choose Photo", systemImage: "photo.badge.plus")
                        .font(.headline)
                        .frame(minWidth: 200)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .clipShape(Capsule())
                .disabled(isLoading)
                .onChange(of: pickerItem) { _, newItem in
                    guard let newItem else { return }
                    isLoading = true
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            onImageSelected(image)
                        }
                        isLoading = false
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Select Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

// MARK: - Review form

private struct ReceiptReviewView: View {
    let image: UIImage
    let rawText: String
    let onSave: (String, Date, [ParsedItem], Double, String) -> Void
    let onCancel: () -> Void

    @State private var storeName: String
    @State private var receiptDate: Date
    @State private var items: [ParsedItem]
    @State private var total: Double
    @State private var currency: String
    @State private var showRawText = false

    init(
        image: UIImage,
        parsed: ParsedReceipt,
        onSave: @escaping (String, Date, [ParsedItem], Double, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.image    = image
        self.rawText  = parsed.rawText
        self.onSave   = onSave
        self.onCancel = onCancel
        _storeName    = State(initialValue: parsed.storeName)
        _receiptDate  = State(initialValue: parsed.date)
        _items        = State(initialValue: parsed.items)
        _total        = State(initialValue: parsed.total)
        _currency     = State(initialValue: parsed.currency)
    }

    var body: some View {
        NavigationStack {
            Form {

                // Scanned image preview
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }

                // Store & date
                Section("Store Info") {
                    HStack {
                        Label("Store", systemImage: "storefront")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        Spacer()
                        TextField("Store name", text: $storeName)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker(
                        selection: $receiptDate,
                        displayedComponents: .date
                    ) {
                        Label("Date", systemImage: "calendar")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }

                // Currency
                Section("Currency") {
                    Picker("Currency", selection: $currency) {
                        Text("RWF – Rwandan Franc").tag("RWF")
                        Text("KES – Kenyan Shilling").tag("KES")
                        Text("UGX – Ugandan Shilling").tag("UGX")
                        Text("TZS – Tanzanian Shilling").tag("TZS")
                        Text("USD – US Dollar").tag("USD")
                        Text("EUR – Euro").tag("EUR")
                    }
                    .pickerStyle(.menu)
                }

                // Line items
                Section {
                    if items.isEmpty {
                        Text("No items detected")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(items) { item in
                            HStack {
                                Text(item.name)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                Spacer()
                                Text("\(currency) \(formatAmount(item.totalPrice))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { offsets in items.remove(atOffsets: offsets) }
                    }
                } header: {
                    HStack {
                        Text("Items (\(items.count))")
                        Spacer()
                        EditButton().font(.caption)
                    }
                }

                // Total
                Section("Total") {
                    HStack {
                        Text(currency)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        TextField("0", value: $total, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                }

                // Debug — raw OCR text
                Section {
                    Button {
                        showRawText.toggle()
                    } label: {
                        HStack {
                            Label("Raw OCR Text", systemImage: "doc.plaintext")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: showRawText ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if showRawText {
                        ScrollView {
                            Text(rawText.isEmpty ? "(no text extracted)" : rawText)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .frame(maxHeight: 260)

                        Button {
                            UIPasteboard.general.string = rawText
                        } label: {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                    }
                } header: {
                    Text("Debug").font(.caption)
                }
            }
            .navigationTitle("Review Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(storeName, receiptDate, items, total, currency)
                    }
                    .fontWeight(.semibold)
                    .disabled(storeName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func formatAmount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

// MARK: - Processing overlay

private struct ProcessingView: View {
    var message: String = "Extracting receipt data…"

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.6)
                .tint(.green)

            VStack(spacing: 6) {
                Text(message)
                    .font(.headline)
                Text("This only takes a moment")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .animation(.easeInOut, value: message)
    }
}

// MARK: - Error view

private struct ScanErrorView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)

            VStack(spacing: 6) {
                Text("Scan Failed")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Dismiss", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
