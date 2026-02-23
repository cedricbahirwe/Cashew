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

            VStack(alignment: .leading, spacing: 4) {
                if receipt.isPending {
                    // Pending: no store name yet
                    HStack(spacing: 6) {
                        Text("Pending")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)

                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text(receipt.storeName.isEmpty ? "Unknown Store" : receipt.storeName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }

                Text(receipt.receiptDate, format: .dateTime.day().month(.wide).year())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !receipt.isPending {
                    Text("\(receipt.items.count) item\(receipt.items.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if receipt.isPending {
                Text("–")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                Text(receipt.formattedTotal)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.green)
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
                .clipShape(RoundedRectangle(cornerRadius: 10))
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
