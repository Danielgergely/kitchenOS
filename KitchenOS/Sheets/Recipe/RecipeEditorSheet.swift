//
//  AddRecipeSheet.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/17/26.
//
import SwiftUI
import SwiftData
import PhotosUI
import GoogleGenerativeAI

struct RecipeEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var recipeToEdit: Recipe?
    
    @State private var title = ""
    @State private var summary = ""
    @State private var instructions = ""
    @State private var prepTime = 15
    @State private var cookTime = 20
    @State private var selectedType: FoodType = .mainDish
    
    @Query(sort: \RecipeBook.title) private var books: [RecipeBook]
    @State private var selectedBook: RecipeBook? = nil
    
    @State private var selectedImageData: Data?
    @State private var tempIngredients: [Ingredient] = []
    
    @State private var tempTags: [Tag] = []
    @State private var showingTagSelector = false
    
    @State private var showAISourceSelector = false
    @State private var showCamera = false
    @State private var aiScanPhotoItem: PhotosPickerItem?
    @State private var isScanning = false
    
    @State private var showingImageSourceDialog = false
    @State private var showingImagePicker = false
    
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    // delete stuff
    @State private var showingDeleteConfirmation = false
    var onDelete: (() -> Void)? = nil
        
    var body: some View {
        NavigationStack {
            Form {
                
                // Manual editing
                Section("Basic Info") {
                    HStack(alignment: .top) {
                        Button {
                            showingImageSourceDialog = true
                        } label: {
                            ZStack {
                                if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 160, height: 160)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(radius: 4)
                                        .overlay(alignment: .bottom) {
                                            Text("Change Photo")
                                                .font(.caption)
                                                .padding(6)
                                        }
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
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button {
                            showAISourceSelector = true
                        } label: {
                            ZStack {
                                if isScanning {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 20, weight: .bold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(
                                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(Circle())
                        }
                        .buttonStyle(.borderless)
                        .disabled(isScanning)
                    }
                    .padding(.vertical, 4)
                    
                    TextField("Recipe Title", text: $title)
                    TextField("Short Description", text: $summary)
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(FoodType.allCases, id: \.self) { type in
                            Label {
                                Text(type.info.name)
                            } icon: {
                                Image(type.info.icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                            }
                            .tag(type)
                        }
                    }
                    Picker("Cookbook", selection: $selectedBook) {
                        Text("None").tag(RecipeBook?(nil))
                        
                        ForEach(books) { book in
                            Text(book.title).tag(RecipeBook?(book))
                        }
                    }
                }
                
                Section("Tags") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button {
                                showingTagSelector = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Tag")
                                }
                                .font(.subheadline.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.15))
                                .foregroundStyle(.primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.borderless)
                            
                            ForEach(tempTags) { tag in
                                TagPill(tag: tag)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Timing (Minutes)") {
                    HStack {
                        Text("Prep")
                        Spacer()
                        TextField("0", value: $prepTime, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Cook")
                        Spacer()
                        TextField("0", value: $cookTime, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Ingredients") {
                    if tempIngredients.isEmpty {
                        Text("No ingredients added.")
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                    
                    ForEach(tempIngredients) { ingredient in
                        EditIngredientsRow(ingredient: ingredient) {
                            if let idx = tempIngredients.firstIndex(where: { $0.id == ingredient.id }) {
                                tempIngredients.remove(at: idx)
                            }
                        }
                    }
                    Button {
                        withAnimation {
                            let newIngredient = Ingredient(
                                id: UUID(),
                                name: "",
                                amount: 1.0,
                                unit: .piece,
                                category: .food,
                                tags: []
                            )
                            tempIngredients.append(newIngredient)
                        }
                    } label: {
                        Label("Add Ingredient", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }
                
                Section("Instructions") {
                    TextEditor(text: $instructions)
                        .frame(minHeight: 150)
                        .overlay(
                            Text("Write instructions here ...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 8)
                                .opacity(instructions.isEmpty ? 1.0 : 0.0),
                            alignment: .topLeading
                        )
                }
                if recipeToEdit != nil {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Text("Delete Recipe")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle(recipeToEdit == nil ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                // Save button
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRecipe() }
                        .disabled(title.isEmpty)
                }
            }
            .confirmationDialog("Scan Recipe", isPresented: $showAISourceSelector) {
                Button("Take Photo") {
                    showCamera = true
                }
                PhotosPicker("Choose from Library", selection: $aiScanPhotoItem, matching: .images)
                Button("Cancel", role: .cancel) {}
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
                if selectedImageData != nil {
                    Button("Remove Photo", role: .destructive) {
                        withAnimation { selectedImageData = nil }
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Delete recipe?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteRecipe()
                }
                Button("Cancel", role: .cancel) { }
            } message:  {
                Text("Recipe \(recipeToEdit?.title ?? "") will be deleted")
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(selectedImage: Binding (
                    get: { nil },
                    set: { newImage in
                        if let image = newImage {
                            processImageWithAI(image)
                        }
                    }
                ))
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImageData, sourceType: imageSourceType)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showingTagSelector) {
                TagSelectorSheet(selectedTags: $tempTags)
            }
            .task(id: aiScanPhotoItem) {
                if let data = try? await aiScanPhotoItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    
                    processImageWithAI(image)
                }
            }
            .onAppear {
                if let recipe = recipeToEdit {
                    title = recipe.title
                    summary = recipe.summary
                    instructions = recipe.instructions
                    prepTime = recipe.prepTime.prepTime
                    cookTime = recipe.prepTime.cookingTime
                    selectedType = recipe.type
                    selectedImageData = recipe.image
                    selectedBook = recipe.book
                    tempTags = recipe.tags
                    
                    tempIngredients = recipe.ingredients.map { oldIng in
                        Ingredient(
                            id: oldIng.id,
                            name: oldIng.name,
                            amount: oldIng.amount,
                            unit: oldIng.unit,
                            category: oldIng.category,
                            tags: []
                        )
                    }
                }
            }
            .onChange(of: selectedImageData) { oldValue, newValue in
                if let data = newValue, data.count > 1_000_000 {
                    if let image = UIImage(data: data) {
                        print("🗜️ Image is \(data.count / 1_000_000)MB. Compressing...")
                        selectedImageData = image.optimizedForDatabase()
                    }
                }
            }
        }
    }
    
    func saveRecipe() {
        if let existingRecipe = recipeToEdit {
            existingRecipe.title = title
            existingRecipe.summary = summary
            existingRecipe.instructions = instructions
            existingRecipe.image = selectedImageData
            existingRecipe.type = selectedType
            existingRecipe.prepTime = PreparationTime(prepTime: prepTime, cookingTime: cookTime)
            existingRecipe.book = selectedBook
            existingRecipe.tags = tempTags
            
            existingRecipe.ingredients.forEach{modelContext.delete($0)}
            existingRecipe.ingredients = tempIngredients
            
        } else {
            let newRecipe = Recipe(
                title: title,
                summary: summary,
                instructions: instructions,
                image: selectedImageData,
                type: selectedType,
                prepTime: PreparationTime(prepTime: prepTime, cookingTime: cookTime),
                ingredients: tempIngredients,
                tags: tempTags
            )
            newRecipe.book = selectedBook
            modelContext.insert(newRecipe)
        }
        dismiss()
    }
    
    func processImageWithAI(_ image: UIImage) {
        isScanning = true
        
        Task {
            do {
                let extracted = try await AIService.shared.extractRecipe(from: image)
                
                // Push the data back to the Main Thread so the UI updates
                await MainActor.run {
                    self.title = extracted.title ?? "Scanned Recipe"
                    self.summary = extracted.summary ?? ""
                    self.instructions = extracted.instructions ?? ""
                    self.prepTime = extracted.prepTime ?? 0
                    self.cookTime = extracted.cookTime ?? 0
                    
                    if let aiIngredients = extracted.ingredients {
                        self.tempIngredients = aiIngredients.compactMap { extIng in
                            let name = extIng.name ?? "Unknown Ingredient"
                            let amount = extIng.amount ?? 1.0
                            let unitString = extIng.unit ?? "piece"
                            
                            let matchedUnit = Unit(rawValue: unitString.lowercased()) ?? .piece
                            
                            return Ingredient(
                                id: UUID(),
                                name: name,
                                amount: amount,
                                unit: matchedUnit,
                                category: .food,
                                tags: []
                            )
                        }
                    }
                    
                    self.isScanning = false
                }
                
            } catch {
                print("AI Extraction Failed: \(error.localizedDescription)")
                await MainActor.run { isScanning = false }
            }
        }
    }
    
    func deleteRecipe() {
        if let recipe = recipeToEdit {
            modelContext.delete(recipe)
            onDelete?()
        }
        dismiss()
    }
}

