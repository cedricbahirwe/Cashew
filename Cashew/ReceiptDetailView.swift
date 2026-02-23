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
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
                // Gradient scrim over the bottom quarter only
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                }
                // Badge pinned to bottom-trailing corner
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                        Text("View full receipt")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5), in: Capsule())
                    .padding(10)
                }
                .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    // MARK: - Pending state

    private var pendingBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                // Status row
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.title3)
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Awaiting Processing")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Will be extracted once the Cashew API is connected.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()

                Divider()
                    .padding(.horizontal)

                // Receipt date
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(receipt.receiptDate.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )

            scannedAtChip
        }
    }

    // MARK: - Complete state

    private var completeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main info card
            VStack(spacing: 0) {
                // Store name + date
                VStack(alignment: .leading, spacing: 10) {
                    Text(receipt.storeName.isEmpty ? "Unknown Store" : receipt.storeName)
                        .font(.title3)
                        .fontWeight(.bold)

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(receipt.receiptDate.formatted(date: .long, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()

                Divider()
                    .padding(.horizontal)

                // Total
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total paid")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(receipt.formattedTotal)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.green.opacity(0.2))
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 16))

            // Scan timestamp — clearly labelled as app metadata
            scannedAtChip
        }
    }

    private var scannedAtChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.down.to.line")
                .font(.caption2)
            Text("Added to Cashew · \(receipt.scannedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
        }
        .foregroundStyle(.tertiary)
        .padding(.leading, 4)
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
        ZStack {
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

        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 45, height: 45)
                    .background(.white, in: .circle)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            }
            .padding()
        }
    }
}
