//
//  SharePlanSheet.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 5/19/26.
//

import SwiftUI
import CloudKit

// Custom share-plan sheet.
//
// Why not UICloudSharingController(preparationHandler:)?
// That controller shows a blank UI when the CloudKit zone isn't ready yet — it has
// no internal fallback for errors. Instead, we create the CKShare ourselves, then hand
// the resulting URL to SwiftUI's ShareLink, which shows the standard iOS share sheet
// (Messages, AirDrop, Copy Link, Mail…) and always works.
struct SharePlanSheet: View {
    let coordinator: CloudKitSharingCoordinator
    var onDismiss: (() -> Void)? = nil

    @State private var phase: Phase = .creating
    @Environment(\.dismiss) private var dismiss

    enum Phase {
        case creating
        case ready(URL)
        case copied(URL)
        case error(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                content
                Spacer()
            }
            .padding(32)
            .navigationTitle("Share Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                        onDismiss?()
                    }
                }
            }
        }
        .task { await createShare() }
    }

    // MARK: - Phase views

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .creating:
            creatingView

        case .ready(let url), .copied(let url):
            readyView(url: url)

        case .error(let message):
            errorView(message: message)
        }
    }

    private var creatingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Creating invite link…")
                .foregroundStyle(.secondary)
        }
    }

    private func readyView(url: URL) -> some View {
        VStack(spacing: 28) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Invite someone to your plan")
                    .font(.title2.bold())
                Text("Send this link to a partner or family member. They'll be able to view and edit your meal plan together with you.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            // Link preview
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(spacing: 12) {
                // ShareLink: opens the native iOS share sheet (Messages, AirDrop, Mail, etc.)
                ShareLink(
                    item: url,
                    subject: Text("Join My Meal Plan"),
                    message: Text("I'm using MealOS to plan our meals. Tap the link to join my household plan.")
                ) {
                    Label("Send Invite Link", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .font(.body.bold())
                }

                Button {
                    UIPasteboard.general.url = url
                    withAnimation { phase = .copied(url) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { phase = .ready(url) }
                    }
                } label: {
                    Label(
                        isCopied ? "Copied!" : "Copy Link",
                        systemImage: isCopied ? "checkmark" : "link"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            Text("Couldn't Create Share Link")
                .font(.title3.bold())

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Try Again") {
                Task { await createShare() }
            }
            .buttonStyle(.borderedProminent)

            Button("Open iCloud Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private var isCopied: Bool {
        if case .copied = phase { return true }
        return false
    }

    // MARK: - Share creation

    private func createShare() async {
        phase = .creating

        await withCheckedContinuation { continuation in
            coordinator.prepareShare { share, _, error in
                DispatchQueue.main.async {
                    if let error {
                        phase = .error(friendlyError(error))
                    } else if let url = share?.url {
                        phase = .ready(url)
                    } else {
                        phase = .error("iCloud returned a share but no link was generated. Make sure you have at least one recipe or meal saved, wait a moment for iCloud to sync, then try again.")
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func friendlyError(_ error: Error) -> String {
        if let ck = error as? CKError {
            switch ck.code {
            case .notAuthenticated:
                return "You're not signed in to iCloud. Go to Settings → Apple ID to sign in, then try again."
            case .networkUnavailable, .networkFailure:
                return "No internet connection. Connect to Wi-Fi or mobile data and try again."
            case .serverRejectedRequest:
                return "iCloud isn't ready yet. Make sure you have at least one recipe or meal in the app, wait a moment for the first sync, then try again."
            case .quotaExceeded:
                return "Your iCloud storage is full. Free up space in Settings → Apple ID → iCloud, then try again."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}
