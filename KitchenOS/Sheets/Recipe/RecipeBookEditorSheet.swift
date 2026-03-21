//
//  RecipeBookEditorSheet.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/28/26.
//
import SwiftUI
import SwiftData

struct RecipeBookEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var bookToEdit: RecipeBook?
    
    @State private var title: String = ""
    @State private var desc: String = ""
    @State private var coverImageData: Data? = nil
    
    @State private var showingImageSourceDialog = false
    @State private var showingImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    
    // delete stuff
    @State private var showingDeleteConfirmation = false
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                // --- IMAGE SELECTOR SECTION ---
                Section {
                    HStack {
                        Spacer()
                        Button {
                            showingImageSourceDialog = true
                        } label: {
                            if let coverImageData, let uiImage = UIImage(data: coverImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 160, height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(radius: 4)
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                                    .frame(width: 160, height: 160)
                                    .overlay {
                                        VStack(spacing: 8) {
                                            Image(systemName: "camera.fill").font(.title)
                                            Text("Add Cover").font(.caption)
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                // --- TEXT SECTION ---
                Section {
                    TextField("Cookbook Title", text: $title)
                        .font(.headline)
                    TextField("Description (Optional)", text: $desc, axis: .vertical)
                        .lineLimit(3...6)
                }
                if bookToEdit != nil {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Text("Delete Cookbook")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle(bookToEdit == nil ? "New Recipe Book" : "Edit Recipe Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                if let book = bookToEdit {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            let safeTitle = book.title.replacingOccurrences(of: " ", with: "_")
                            
                            if let url = DataExchangeService.generateExportFile(
                                from: book.recipes ?? [],
                                books: [book],
                                filename: "\(safeTitle)_Book.json"
                            ) {
                                exportURL = url
                                showShareSheet = true
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveBook() }
                    .disabled(title.isEmpty)
                }
            }
            .alert("Choose Cover Photo", isPresented: $showingImageSourceDialog) {
                Button("Camera") {
                    imageSourceType = .camera
                    showingImagePicker = true
                }
                Button("Photo Library") {
                    imageSourceType = .photoLibrary
                    showingImagePicker = true
                }
                if coverImageData != nil {
                    Button("Remove Photo", role: .destructive) {
                        withAnimation { coverImageData = nil }
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Delete Cookbook?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteBook()
                }
                Button("Cancel", role: .cancel) { }
            } message:  {
                Text("Cookbook \(bookToEdit?.title ?? "") will be deleted, along with all its recipes.")
            }
            .fullScreenCover(isPresented: $showingImagePicker) {
                ImagePicker(image: $coverImageData, sourceType: imageSourceType)
                    .ignoresSafeArea()
            }
            .onChange(of: coverImageData) { oldValue, newValue in
                if let data = newValue, data.count > 1_000_000 {
                    if let image = UIImage(data: data) {
                        print("🗜️ Book Cover is \(data.count / 1_000_000)MB. Compressing...")
                        coverImageData = image.optimizedForDatabase()
                    }
                }
            }
            .onAppear {
                if let book = bookToEdit {
                    title = book.title
                    desc = book.desc ?? ""
                    coverImageData = book.image
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let exportURL {
                    ShareSheet(activityItems: [exportURL])
                }
            }
        }
    }
    
    func saveBook() {
        if let existingBook = bookToEdit {
            existingBook.title = title
            existingBook.desc = desc
            existingBook.image = coverImageData
        } else {
            let newBook = RecipeBook(title: title, desc: desc, image: coverImageData)
            modelContext.insert(newBook)
        }
        dismiss()
    }
    
    func deleteBook() {
        if let book = bookToEdit {
            dismiss()
            
            onDelete?()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                modelContext.delete(book)
                try? modelContext.save()
            }
        } else {
            dismiss()
        }
    }
}

