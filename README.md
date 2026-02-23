# Cashew

Personal receipt scanner for iOS — scan, store and track your spending with Apple Intelligence.

## What it does

Cashew lets you scan supermarket receipts with your camera, automatically extracts the store name, date, and total, and saves everything locally alongside the receipt image.

## How it works

**On Apple Intelligence devices (iPhone 15 Pro / iPhone 16 series)**
Scan a receipt → Vision OCR extracts the text → Apple Foundation Models parses the store name, date, and total → you review and save.

**On other devices**
Scan a receipt → image is saved with a *pending* status → extraction will be handled by a future API integration.

RRA fiscal QR codes (found on Rwandan receipts) are detected automatically and used as the most reliable source for the transaction date.

## Features

- Document camera scanning with perspective correction
- Photo library fallback for Simulator / testing
- On-device extraction via Apple Foundation Models (`@Generable` structured output)
- RRA / EBM fiscal QR code parsing for accurate dates
- Pending status for receipts awaiting API processing
- Hero image transition (matched geometry effect) with pinch-to-zoom, pan, swipe-to-dismiss
- Local persistence with SwiftData

## Tech stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Persistence | SwiftData |
| OCR | Vision (`VNRecognizeTextRequest`) |
| QR detection | Vision (`VNDetectBarcodesRequest`) |
| Extraction | Apple Foundation Models (`LanguageModelSession`) |
| Document scanning | VisionKit (`VNDocumentCameraViewController`) |

## Requirements

- iOS 18.0+
- Xcode 16+
- Apple Intelligence requires iPhone 15 Pro or iPhone 16 family with Apple Intelligence enabled
