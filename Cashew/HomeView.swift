//
//  HomeView.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.scannedAt, order: .reverse) private var receipts: [Receipt]

    @State private var showScanner = false
    @State private var searchText = ""

    private var filteredReceipts: [Receipt] {
        guard !searchText.isEmpty else { return receipts }
        return receipts.filter {
            $0.storeName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if receipts.isEmpty {
                    EmptyStateView(onScan: { showScanner = true })
                } else {
                    receiptList
                }
            }
            .navigationTitle("Cashew")
            .searchable(text: $searchText, prompt: "Search receipts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                ReceiptScannerView()
            }
        }
    }

    // MARK: - Subviews

    private var receiptList: some View {
        List {
            if !filteredReceipts.isEmpty {
                Section {
                    ForEach(filteredReceipts) { receipt in
                        NavigationLink {
                            ReceiptDetailView(receipt: receipt)
                        } label: {
                            ReceiptCard(receipt: receipt)
                        }
                    }
                    .onDelete(perform: deleteReceipts)
                } header: {
                    Text("\(filteredReceipts.count) receipt\(filteredReceipts.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func deleteReceipts(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredReceipts[index])
            }
        }
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    let onScan: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(Color.green.gradient)

            VStack(spacing: 8) {
                Text("No receipts yet")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Scan a supermarket receipt\nto get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onScan) {
                Label("Scan Receipt", systemImage: "camera")
                    .font(.headline)
                    .frame(minWidth: 180)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
