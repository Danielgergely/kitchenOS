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
        VStack(alignment: .leading, spacing: 8) {
            // 1. The Cover Image
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
                
                if let urlString = book.coverImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image.resizable()
                                 .scaledToFill()
                        case .failure:
                            Image(systemName: "book.closed").foregroundStyle(.tertiary).font(.largeTitle)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "book.closed").foregroundStyle(.tertiary).font(.largeTitle)
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            
            // 2. The Details
            Text(book.title)
                .font(.headline)
                .lineLimit(1)
            
            if let desc = book.description {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 0)
            
            // 3. The Price / Download Button
            Button {
                onDownload()
            } label: {
                HStack {
                    Spacer()
                    if isDownloading {
                        ProgressView().controlSize(.small).tint(.white)
                    } else if isOwned {
                        // Show a checkmark if they already have it in their library
                        Image(systemName: "checkmark")
                    } else {
                        Text(book.price == 0 ? "GET" : "$\(book.price, specifier: "%.2f")")
                            .font(.subheadline.bold())
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                // Grey out the button if owned
                .background(isOwned ? Color.secondary : (book.price == 0 ? Color.blue : Color.green))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            // Disable the button if downloading, already owned, or broken link
            .disabled(isDownloading || isOwned || book.jsonDownloadUrl == nil)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}
