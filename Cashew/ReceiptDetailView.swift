//
//  ReceiptDetailView.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//

import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt

    @State private var showFullImage = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Receipt image — constrained preview, tap to expand
                if let data = receipt.imageData, let uiImage = UIImage(data: data) {
                    receiptImagePreview(uiImage)
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
        .fullScreenCover(isPresented: $showFullImage) {
            if let data = receipt.imageData, let uiImage = UIImage(data: data) {
                FullImageViewer(image: uiImage)
            }
        }
    }

    // MARK: - Image preview

    private func receiptImagePreview(_ image: UIImage) -> some View {
        Button {
            showFullImage = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                // Expand hint badge
                Label("View", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(10)
            }
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
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

// MARK: - Full-screen image viewer

private struct FullImageViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        // Pinch to zoom
                        MagnifyGesture()
                            .onChanged { value in
                                let delta = value.magnification / lastScale
                                lastScale = value.magnification
                                scale = min(max(scale * delta, 1), 5)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1 { withAnimation(.spring) { scale = 1; offset = .zero } }
                            },
                        // Pan when zoomed in
                        DragGesture()
                            .onChanged { value in
                                guard scale > 1 else { return }
                                offset = CGSize(
                                    width:  lastOffset.width  + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring) {
                        scale  = scale > 1 ? 1 : 2.5
                        offset = .zero
                        lastOffset = .zero
                    }
                }
                .animation(.interactiveSpring, value: scale)

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
        }
    }
}
