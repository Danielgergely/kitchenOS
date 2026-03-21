//
//  RecipeStoreView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/21/26.
//
import SwiftUI
import SwiftData

struct RecipeStoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var existingBooks: [RecipeBook]
    
    @State private var availableBooks: [StoreRecipeBook] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @State private var downloadingBookId: UUID? = nil
    @State private var showingSuccessToast = false
    @State private var successMessage = ""
    
    @State private var pendingImport: TransferBackup? = nil
    @State private var showingOverwriteAlert = false
    @State private var collidingBookName = ""
    
    let gridColumns = [GridItem(.adaptive(minimum: 240, maximum: 300), spacing: 20)]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Loading Storefront...").padding(.top, 50)
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).padding(.top, 50)
                } else {
                    VStack(alignment: .leading) {
                        Text("Featured Cookbooks")
                            .font(.title2.bold())
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        storeGrid
                    }
                }
            }
            .navigationTitle("Recipe Store")
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationDestination(for: StoreRecipeBook.self) { book in
                StoreBookDetailView(
                    book: book,
                    isOwned: isBookOwned(storeBookId: book.id),
                    isDownloading: downloadingBookId == book.id
                ) {
                    handlePurchase(book: book)
                }
            }
            .task {
                await fetchBooks()
            }
            .overlay(alignment: .top) {
                if showingSuccessToast {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.green)
                        .clipShape(Capsule())
                        .shadow(radius: 5)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 16)
                }
            }
            .alert("Book Already Exists", isPresented: $showingOverwriteAlert) {
                Button("Overwrite", role: .destructive) {
                    if let backup = pendingImport {
                        try? DataExchangeService.executeImport(backup: backup, context: modelContext, overwrite: true)
                        triggerSuccessAnimation(for: collidingBookName)
                        pendingImport = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: {
                Text("You already have '\(collidingBookName)' in your library. Do you want to overwrite it and replace all its recipes?")
            }
        }
    }
    
    // MARK: - Extracted Views
    
    @ViewBuilder
    private var storeGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 24) {
            ForEach(availableBooks, id: \.id) { book in
                NavigationLink(value: book) {
                    StoreBookSquare(
                        book: book,
                        isOwned: isBookOwned(storeBookId: book.id),
                        isDownloading: downloadingBookId == book.id
                    ) {
                        handlePurchase(book: book)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
    
    // MARK: - Functions
    
    private func triggerSuccessAnimation(for title: String) {
        successMessage = "\(title) Downloaded!"
        withAnimation(.spring()) {
            showingSuccessToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut) {
                showingSuccessToast = false
            }
        }
    }
    
    private func fetchBooks() async {
        do {
            availableBooks = try await RecipeStoreService.shared.fetchAvailableBooks()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func handlePurchase(book: StoreRecipeBook) {
        if book.price > 0 {
            print("💰 Simulating purchase for \(book.storekitId ?? "Unknown ID")")
        }
        downloadAndImport(book: book)
    }
    
    private func downloadAndImport(book: StoreRecipeBook) {
        guard let rawUrlString = book.jsonDownloadUrl else { return }
        let cleanedUrl = rawUrlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: cleanedUrl) else { return }
        
        downloadingBookId = book.id
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let backup = try JSONDecoder().decode(TransferBackup.self, from: data)
                
                await MainActor.run {
                    downloadingBookId = nil
                    
                    if let incomingBook = backup.books.first {
                        // Check if we already own it via ID, or if there's a title collision with an unlinked book
                        let alreadyOwned = isBookOwned(storeBookId: book.id)
                        let titleCollision = existingBooks.contains(where: { $0.title == incomingBook.title && $0.storefrontId == nil })
                        
                        if alreadyOwned || titleCollision {
                            self.collidingBookName = incomingBook.title
                            self.pendingImport = backup
                            self.showingOverwriteAlert = true
                        } else {
                            // Import the data
                            try? DataExchangeService.executeImport(backup: backup, context: modelContext, overwrite: false)
                            
                            // Find the newly imported book and permanently link it!
                            let fetchDescriptor = FetchDescriptor<RecipeBook>(predicate: #Predicate { $0.title == incomingBook.title })
                            if let newlyImportedBook = try? modelContext.fetch(fetchDescriptor).first {
                                newlyImportedBook.storefrontId = book.id
                                try? modelContext.save()
                            }
                            
                            triggerSuccessAnimation(for: book.title)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Download failed: \(error.localizedDescription)")
                    downloadingBookId = nil
                }
            }
        }
    }
    
    private func isBookOwned(storeBookId: UUID) -> Bool {
        return existingBooks.contains(where: { $0.storefrontId == storeBookId })
    }
}
