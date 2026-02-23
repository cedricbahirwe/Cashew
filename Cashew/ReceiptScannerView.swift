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
        case processing(String)
        /// Apple Intelligence succeeded — user reviews and edits before saving.
        case reviewing(UIImage, ParsedReceipt)
        /// Non-AI device — image captured, waiting for API processing.
        case confirming(UIImage, Date)
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
                SimulatorPickerView(onImageSelected: handleImage, onCancel: { dismiss() })
            }

        // ── Processing ───────────────────────────────────────────────────────
        case .processing(let message):
            ProcessingView(message: message)

        // ── Review (AI path) ─────────────────────────────────────────────────
        case .reviewing(let image, let parsed):
            ReceiptReviewView(image: image, parsed: parsed) { storeName, date, items, total, currency in
                saveReceipt(
                    image: image,
                    storeName: storeName,
                    date: date,
                    items: items,
                    total: total,
                    currency: currency,
                    rawText: parsed.rawText,
                    status: .complete
                )
            } onCancel: {
                dismiss()
            }

        // ── Confirm (pending path) ───────────────────────────────────────────
        case .confirming(let image, let date):
            PendingConfirmView(image: image, date: date) {
                savePendingReceipt(image: image, date: date)
            } onCancel: {
                dismiss()
            }

        // ── Error ────────────────────────────────────────────────────────────
        case .error(let message):
            ScanErrorView(message: message, onDismiss: { dismiss() })
        }
    }

    // MARK: - Scan entry points

    private func handleScan(_ scan: VNDocumentCameraScan) {
        handleImage(scan.imageOfPage(at: 0))
    }

    /// Shared pipeline for both camera and photo-picker images.
    private func handleImage(_ image: UIImage) {
        stage = .processing("Scanning receipt…")

        Task {
            // Always run OCR + QR in parallel (fast, works on all devices).
            async let ocrTask = VisionService.recognizeText(from: image)
            async let qrTask  = VisionService.detectQRCode(from: image)

            let rawText   = await ocrTask
            let qrPayload = await qrTask

            // Extract date from QR if available (machine-encoded, most reliable).
            let qrDate = qrPayload
                .flatMap { ReceiptParser.parseRRAQRCode($0) }
                .map    { $0.date }

            // ── Apple Intelligence path ──────────────────────────────────────
            if #available(iOS 18.1, *), FoundationModelService.isAvailable {
                await MainActor.run {
                    stage = .processing("Analysing with Apple Intelligence…")
                }

                if let extracted = await FoundationModelService.extractReceiptData(from: rawText) {
                    let parsedItems = extracted.items.map {
                        ParsedItem(
                            name:       $0.name,
                            quantity:   $0.quantity,
                            unitPrice:  $0.unitPrice,
                            totalPrice: $0.totalPrice
                        )
                    }
                    let parsed = ParsedReceipt(
                        storeName: extracted.storeName,
                        date:      qrDate ?? ReceiptParser.extractDate(fromRawText: rawText),
                        items:     parsedItems,
                        total:     extracted.totalAmount,
                        currency:  extracted.currency,
                        rawText:   rawText
                    )
                    await MainActor.run { stage = .reviewing(image, parsed) }
                    return
                }
            }

            // ── Pending path (no Apple Intelligence) ────────────────────────
            // Image is captured; extraction will be done by the API later.
            let fallbackDate = qrDate ?? ReceiptParser.extractDate(fromRawText: rawText)
            await MainActor.run {
                stage = .confirming(image, fallbackDate)
            }
        }
    }

    // MARK: - Save helpers

    private func saveReceipt(
        image: UIImage,
        storeName: String,
        date: Date,
        items: [ParsedItem],
        total: Double,
        currency: String,
        rawText: String,
        status: ReceiptStatus
    ) {
        let receiptItems = items.map {
            ReceiptItem(
                name:       $0.name,
                quantity:   $0.quantity,
                unitPrice:  $0.unitPrice,
                totalPrice: $0.totalPrice
            )
        }
        modelContext.insert(Receipt(
            storeName:   storeName,
            receiptDate: date,
            totalAmount: total,
            currency:    currency,
            imageData:   image.jpegData(compressionQuality: 0.75),
            rawText:     rawText,
            items:       receiptItems,
            status:      status
        ))
        dismiss()
    }

    private func savePendingReceipt(image: UIImage, date: Date) {
        modelContext.insert(Receipt(
            storeName:   "",
            receiptDate: date,
            totalAmount: 0,
            currency:    "RWF",
            imageData:   image.jpegData(compressionQuality: 0.75),
            rawText:     "",
            items:       [],
            status:      .pending
        ))
        dismiss()
    }
}

// MARK: - Pending confirm view

/// Shown on non-Apple-Intelligence devices after the image is captured.
/// The user just confirms the capture; extraction will happen via API later.
private struct PendingConfirmView: View {
    let image: UIImage
    let date: Date
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Receipt image preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                    .padding()

                // Status card
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.orange.gradient)

                    VStack(spacing: 6) {
                        Text("Receipt captured")
                            .font(.headline)
                        Text("Data extraction requires Apple Intelligence.\nThis receipt will be processed once connected to the Cashew API.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    HStack {
                        Label(
                            date.formatted(date: .long, time: .omitted),
                            systemImage: "calendar"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)

                Spacer()

                Button(action: onSave) {
                    Text("Save Receipt")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Confirm Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

// MARK: - Simulator photo picker

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

// MARK: - Review form (Apple Intelligence path)

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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                    if item.quantity > 1 {
                                        Text("Qty: \(item.quantity)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
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

                // Debug — raw OCR
                Section {
                    Button { showRawText.toggle() } label: {
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
    var message: String

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.6)
                .tint(.green)

            VStack(spacing: 6) {
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("This only takes a moment")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
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
