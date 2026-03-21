//
//  StoreBookSquare.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/21/26.
//
import SwiftUI

struct StoreBookSquare: View {
    let book: StoreRecipeBook
    let isOwned: Bool
    let isDownloading: Bool
    let onDownload: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // --- Cover Image ---
            ZStack {
                if let urlString = book.coverImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            Color.clear
                                .overlay(
                                    image
                                        .resizable()
                                        .scaledToFill()
                                )
                                .clipped()
                        } else {
                            ZStack {
                                Color(uiColor: .secondarySystemBackground)
                                ProgressView()
                            }
                        }
                    }
                } else {
                    ZStack {
                        Color(uiColor: .secondarySystemBackground)
                        Image(systemName: "book.closed").foregroundStyle(.tertiary).font(.largeTitle)
                    }
                }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            
            // --- Details & Button Area ---
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(book.title)
                    .font(.headline)
                    .lineLimit(1)
                
                // Recipe Count
                if let count = book.recipeCount {
                    Text("\(count) Recipes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Bottom Row: Price & Button
                HStack(alignment: .center) {
                    Text(book.price == 0 ? "Free" : "$\(book.price, specifier: "%.2f")")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        onDownload()
                    } label: {
                        HStack(spacing: 4) {
                            if isDownloading {
                                ProgressView().controlSize(.small)
                            } else if isOwned {
                                Text("In Library")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.green)
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.green)
                            } else {
                                Text("GET").font(.caption.bold())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(isOwned ? Color(uiColor: .tertiarySystemFill) : Color.blue.opacity(0.15))
                        .foregroundStyle(isOwned ? Color.secondary : Color.blue)
                        .clipShape(Capsule())
                    }
                    .disabled(isDownloading || isOwned || book.jsonDownloadUrl == nil)
                }
                .padding(.top, 4)
            }
            .padding(12)
        }
        // --- CARD STYLING ---
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1) // Subtle border
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4) // Drop shadow
        .contentShape(Rectangle()) // Ensures the whole card is tappable
    }
}

