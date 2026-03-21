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
    
    let gridColumns = [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                // --- HERO BACKGROUND & COVER ---
                ZStack(alignment: .bottom) {
                    if let urlString = book.coverImageUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable()
                                     .scaledToFill()
                                     .frame(height: 320)
                                     .blur(radius: 30)
                                     .clipped()
                                     .overlay(
                                        LinearGradient(
                                            colors: [.clear, Color(uiColor: .systemBackground)],
                                            startPoint: .center,
                                            endPoint: .bottom
                                        )
                                     )
                            } else {
                                Color.secondary.opacity(0.1).frame(height: 320)
                            }
                        }
                    }
                    
                    // The Actual Crisp Cover Image
                    if let urlString = book.coverImageUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable()
                                     .scaledToFill()
                                     .frame(width: 180, height: 180)
                                     .clipShape(RoundedRectangle(cornerRadius: 16))
                                     .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                            }
                        }
                        .offset(y: 40)
                    }
                }
                .padding(.bottom, 60)
                
                
                VStack(spacing: 28) {
                    // --- TITLE & INFO ---
                    VStack(spacing: 8) {
                        Text(book.title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        
                        if let count = book.recipeCount {
                            Label("\(count) Recipes", systemImage: "book.pages")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // --- DESCRIPTION ---
                    if let desc = book.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About this Cookbook")
                                .font(.title3.bold())
                            Text(desc)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                    
                    // --- RECIPES PREVIEW GRID ---
                    if let previews = book.previewRecipes, !previews.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Included Recipes")
                                .font(.title3.bold())
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(previews, id: \.title) { preview in
                                    SimpleRecipeSquare(preview: preview)
                                        .frame(height: 160)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
    }
}
