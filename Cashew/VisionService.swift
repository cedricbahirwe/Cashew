//
//  VisionService.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//

import Vision
import UIKit

enum VisionService {

    // MARK: - Text recognition (OCR)

    /// Runs Apple's Vision text recognizer on a UIImage and returns the raw extracted string.
    static func recognizeText(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let text = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - QR code detection

    /// Scans the image for any QR code and returns its payload string if found.
    /// On RRA-compliant Rwandan receipts this contains structured fiscal data
    /// (date, time, SDC device ID, cryptographic signatures).
    static func detectQRCode(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, _ in
                let payload = (request.results as? [VNBarcodeObservation])?
                    .first(where: { $0.symbology == .qr })?
                    .payloadStringValue
                continuation.resume(returning: payload)
            }
            request.symbologies = [.qr]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}
