//
//  ReceiptCard.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//

import SwiftUI

struct ReceiptCard: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 14) {
            receiptThumbnail

            // Store name gets the full row — no truncation competition
            VStack(alignment: .leading, spacing: 5) {
                if receipt.isPending {
                    HStack(spacing: 5) {
                        Text("Pending")
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        Image(systemName: "clock.arrow.2.circlepath")
                            .foregroundStyle(.orange)
                    }
                    .font(.subheadline)
                } else {
                    Text(receipt.storeName.isEmpty ? "Unknown Store" : receipt.storeName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }

                HStack {
                    Text(receipt.receiptDate, format: .dateTime.day().month(.abbreviated).year())
                        .foregroundStyle(.secondary)

                    Spacer()

                    if receipt.isPending {
                        Text("Processing…")
                            .foregroundStyle(.orange.opacity(0.8))
                    } else {
                        Text(receipt.formattedTotal)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var receiptThumbnail: some View {
        if let data = receipt.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(.rect(cornerRadius: 10))
                .overlay(alignment: .bottomTrailing) {
                    if receipt.isPending {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .offset(x: 4, y: 4)
                    }
                }
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: receipt.isPending ? "clock.arrow.2.circlepath" : "doc.text")
                        .font(.title3)
                        .foregroundStyle(receipt.isPending ? .orange : .secondary)
                }
        }
    }
}
