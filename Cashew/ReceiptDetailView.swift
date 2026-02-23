//
//  ReceiptDetailView.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//

import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Receipt image
                if let data = receipt.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                        .frame(maxWidth: .infinity)
                }

                if receipt.isPending {
                    pendingBanner
                } else {
                    completeContent
                }
            }
            .padding()
        }
        .navigationTitle(receipt.isPending ? "Pending Receipt" : "Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Pending state

    private var pendingBanner: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Awaiting Processing")
                        .font(.headline)
                    Text("This receipt will be processed once the Cashew API is connected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Captured date from QR (may be set even on pending receipts)
            HStack {
                Label(
                    receipt.receiptDate.formatted(date: .long, time: .omitted),
                    systemImage: "calendar"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()

                Label(
                    receipt.scannedAt.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Complete state

    private var completeContent: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Store header
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.storeName.isEmpty ? "Unknown Store" : receipt.storeName)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 12) {
                    Label(
                        receipt.receiptDate.formatted(date: .long, time: .omitted),
                        systemImage: "calendar"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Label(
                        receipt.scannedAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }

            // Total card
            HStack {
                Text("Total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(receipt.formattedTotal)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

}
