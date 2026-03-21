//
//  StoreBookDetailView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/21/26.
//
import SwiftUI

struct StoreBookDetailView: View {
    let book: StoreRecipeBook
    let isOwned: Bool
    let isDownloading: Bool
    let onDownload: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Cover Image
                if let urlString = book.coverImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.secondary.opacity(0.2)
                        }
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 10)
                }
                
                // Title & Info
                VStack(spacing: 8) {
                    Text(book.title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    
                    if let count = book.recipeCount {
                        Label("\(count) Recipes", systemImage: "list.bullet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Download / Owned Button
                Button {
                    onDownload()
                } label: {
                    HStack {
                        if isDownloading {
                            ProgressView().tint(.white)
                            Text("Downloading...")
                        } else if isOwned {
                            Image(systemName: "checkmark.circle.fill")
                            Text("In Library")
                        } else {
                            Text(book.price == 0 ? "Download for Free" : "Purchase $\(book.price, specifier: "%.2f")")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isOwned ? Color.secondary : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isDownloading || isOwned)
                .padding(.horizontal, 32)
                
                // Description
                if let desc = book.description {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About this Cookbook")
                            .font(.headline)
                        Text(desc)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
