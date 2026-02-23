//
//  ReceiptDetailView.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//

import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt

    @Namespace private var imageNamespace
    @State private var showFullImage = false

    var body: some View {
        ZStack {
            // ── Main scroll content ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 20) {

                if let data = receipt.imageData, let uiImage = UIImage(data: data) {
                    receiptImagePreview(uiImage)
                }

                if receipt.isPending {
                    pendingBanner
                } else {
                    completeContent
                }
                Spacer()
            }
            .padding()
            // Dim the rest of the page while the image is expanded
            .overlay {
                if showFullImage {
                    Color.red.opacity(0.01)   // tiny opacity keeps it hittable for dismiss
//                        .ignoresSafeArea()
                        .onTapGesture { collapseImage() }
                }
            }

            // ── Full-screen overlay (same hierarchy — required for matchedGeometryEffect) ──
            if showFullImage, let data = receipt.imageData, let uiImage = UIImage(data: data) {
                FullImageViewer(
                    image: uiImage,
                    namespace: imageNamespace,
                    onDismiss: collapseImage
                )
//                .ignoresSafeArea()
                .zIndex(1)
            }
        }
        .navigationTitle(receipt.isPending ? "Pending Receipt" : "Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(showFullImage ? .hidden : .visible, for: .navigationBar)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private func expandImage() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            showFullImage = true
        }
    }

    private func collapseImage() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            showFullImage = false
        }
    }

    // MARK: - Image preview

    private func receiptImagePreview(_ image: UIImage) -> some View {
        Button(action: expandImage) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
                // matchedGeometryEffect tags this as the "source" frame
                .matchedGeometryEffect(id: "receiptImage", in: imageNamespace)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                }
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
        // Hide the source while expanded so only the hero image is visible
        .opacity(showFullImage ? 0 : 1)
    }

    // MARK: - Pending state

    private var pendingBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
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

                Divider().padding(.horizontal)

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
            VStack(spacing: 0) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                Divider().padding(.horizontal)

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

            scannedAtChip
        }
    }

    private var scannedAtChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.down.to.line")
            Text("Added: \(receipt.scannedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
        .padding(.leading, 4)
    }
}

// MARK: - Full-screen image viewer

private struct FullImageViewer: View {
    let image: UIImage
    let namespace: Namespace.ID
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.green//.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                // matchedGeometryEffect tags this as the "destination" frame
                .matchedGeometryEffect(id: "receiptImage", in: namespace)
                .scaleEffect(scale)
                .offset(
                    CGSize(
                        width:  offset.width  + dragOffset.width,
                        height: offset.height + dragOffset.height
                    )
                )
                .gesture(
                    SimultaneousGesture(
                        MagnifyGesture()
                            .onChanged { value in
                                let delta = value.magnification / lastScale
                                lastScale = value.magnification
                                scale = min(max(scale * delta, 1), 5)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1 {
                                    withAnimation(.spring) { scale = 1; offset = .zero }
                                }
                            },
                        DragGesture()
                            .onChanged { value in
                                if scale > 1 {
                                    // Pan while zoomed
                                    dragOffset = value.translation
                                } else {
                                    // Swipe down to dismiss
                                    dragOffset = CGSize(width: 0, height: max(0, value.translation.height))
                                }
                            }
                            .onEnded { value in
                                if scale > 1 {
                                    offset = CGSize(
                                        width:  offset.width  + dragOffset.width,
                                        height: offset.height + dragOffset.height
                                    )
                                    dragOffset = .zero
                                    lastOffset = offset
                                } else {
                                    // Dismiss if dragged far enough down
                                    if value.translation.height > 100 {
                                        onDismiss()
                                    } else {
                                        withAnimation(.spring) { dragOffset = .zero }
                                    }
                                }
                            }
                    )
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring) {
                        scale      = scale > 1 ? 1 : 2.5
                        offset     = .zero
                        dragOffset = .zero
                        lastOffset = .zero
                    }
                }
        }
        .offset(y: dragOffset.height * 0.3)
        .overlay(alignment: .topTrailing) {
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 45, height: 45)
                    .background(Color.white, in: Circle())
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            }
            .padding()
            .offset(y: (dragOffset.height * 0.3) > 0 ? dragOffset.height * 0.3 : 0)

        }
    }
}
