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
            // Thumbnail
            receiptThumbnail

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.storeName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(receipt.receiptDate, format: .dateTime.day().month(.wide).year())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(receipt.items.count) item\(receipt.items.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(receipt.formattedTotal)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.green)
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
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "doc.text")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
        }
    }
}
