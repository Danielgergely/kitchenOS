//
//  CookModeView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/21/26.
//
import SwiftUI

struct CookModeView: View {
    let recipe: Recipe
    @Environment(\.dismiss) var dismiss
    @State private var completedSteps: Set<Int> = []
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                // --- LEFT SIDE: INSTRUCTIONS ---
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // --- FADE-OUT HERO IMAGE ---
                        ZStack(alignment: .bottom) {
                            if let data = recipe.image, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 250)
                                    .clipped()
                            }
                            
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .clear, location: 0.5),
                                    .init(color: Color(uiColor: .systemBackground), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .frame(height: 250)
                        
                        // --- INSTRUCTION CONTENT ---
                        VStack(alignment: .leading, spacing: 30) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cook Mode")
                                    .font(.caption.bold())
                                    .foregroundColor(.blue)
                                
                                Text(recipe.title)
                                    .font(.largeTitle.bold())
                            }
                            
                            let steps = recipe.instructions.components(separatedBy: .newlines)
                                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                            
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 20) {
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            if completedSteps.contains(index) {
                                                completedSteps.remove(index)
                                            } else {
                                                completedSteps.insert(index)
                                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                                impact.impactOccurred()
                                            }
                                        }
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .stroke(completedSteps.contains(index) ? Color.green : Color.white.opacity(0.2), lineWidth: 2)
                                                .frame(width: 32, height: 32)
                                            
                                            Circle()
                                                .fill(completedSteps.contains(index) ? Color.green : Color.clear)
                                                .frame(width: 32, height: 32)
                                            
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                                .opacity(completedSteps.contains(index) ? 1 : 0)
                                                .scaleEffect(completedSteps.contains(index) ? 1.0 : 0.5)
                                        }
                                    }
                                    .scaleEffect(completedSteps.contains(index) ? 1.1 : 1.0)
                                    
                                    SmartInstructionText(step: step, ingredients: recipe.ingredients)
                                        .font(.title3)
                                        .lineSpacing(8)
                                        .opacity(completedSteps.contains(index) ? 0.3 : 1.0)
                                }
                            }
                        }
                        .padding(40)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .systemBackground))
                
                Divider()
                
                // --- RIGHT SIDE: INGREDIENTS SIDEBAR ---
                VStack(alignment: .leading, spacing: 0) {
                    Text("Ingredients")
                        .font(.title3.bold())
                        .padding(.top, 80)
                        .padding([.horizontal, .bottom])
                    
                    List(recipe.ingredients) { ingredient in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ingredient.name).font(.subheadline.bold())
                            Text("\(ingredient.amount, format: .number) \(ingredient.unit.rawValue)").font(.caption).foregroundColor(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                .frame(width: 300)
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.4))
            }
            
            // --- FLOATING EXIT BUTTON ---
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .background(Color.black.opacity(0.2))
                    .clipShape(Circle())
            }
            .padding(.trailing, 20)
            .padding(.top, 40)
        }
        .ignoresSafeArea()
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
