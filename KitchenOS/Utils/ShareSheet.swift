//
//  ShareSheet.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/21/26.
//

import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Identifiable wrapper so an exported file URL can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}
