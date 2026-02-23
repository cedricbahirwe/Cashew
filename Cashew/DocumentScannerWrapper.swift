//
//  DocumentScannerWrapper.swift
//  Cashew
//
//  Created by Cédric Bahirwe on 22/02/2026.
//

import SwiftUI
import VisionKit

/// Wraps `VNDocumentCameraViewController` so it can be embedded in SwiftUI.
struct DocumentScannerWrapper: UIViewControllerRepresentable {
    var onCompletion: (VNDocumentCameraScan) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onCompletion: (VNDocumentCameraScan) -> Void
        let onCancel: () -> Void

        init(
            onCompletion: @escaping (VNDocumentCameraScan) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onCompletion = onCompletion
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            onCompletion(scan)
        }

        func documentCameraViewControllerDidCancel(
            _ controller: VNDocumentCameraViewController
        ) {
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onCancel()
        }
    }
}
