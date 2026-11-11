//
//  TextImportSheet.swift
//  KitchenOS
//
//  Paste a recipe (e.g. copied from Apple Notes) or pick a text file.
//  Notes has no API for other apps, so copy/paste or Share → Save to Files
//  is how a note gets here.
//

import SwiftUI
import UniformTypeIdentifiers

struct TextImportSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onImport: (String) -> Void

    @State private var text = ""
    @State private var showingFileImporter = false
    @State private var fileError: String?

    private static let fileTypes: [UTType] = [.plainText, .rtf, .rtfd, .html, UTType("net.daringfireball.markdown")]
        .compactMap { $0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 300)
                        .overlay(alignment: .topLeading) {
                            Text("Paste the recipe here …")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .opacity(text.isEmpty ? 1 : 0)
                                .allowsHitTesting(false)
                        }
                } footer: {
                    Text("In Notes, select the recipe and copy it, or use Share → Save to Files and pick the file here.")
                }

                Section {
                    Button {
                        if let pasted = UIPasteboard.general.string { text = pasted }
                    } label: {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                    }
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Choose File", systemImage: "folder")
                    }
                }
            }
            .navigationTitle("Import from Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Extract") {
                        onImport(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: Self.fileTypes) { result in
                do {
                    text = try Self.readText(from: result.get())
                } catch {
                    fileError = error.localizedDescription
                }
            }
            .alert("Couldn't Read File", isPresented: Binding(
                get: { fileError != nil },
                set: { if !$0 { fileError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(fileError ?? "")
            }
        }
    }

    /// Plain text as-is; RTF and HTML (what Notes exports) stripped to their text.
    static func readText(from url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let type = UTType(filenameExtension: url.pathExtension)
        let documentType: NSAttributedString.DocumentType? = switch type {
        case let t? where t.conforms(to: .rtfd): .rtfd
        case let t? where t.conforms(to: .rtf): .rtf
        case let t? where t.conforms(to: .html): .html
        default: nil
        }

        if let documentType {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: documentType,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ]
            let attributed = documentType == .rtfd
                ? try NSAttributedString(url: url, options: options, documentAttributes: nil)
                : try NSAttributedString(data: Data(contentsOf: url), options: options, documentAttributes: nil)
            return attributed.string
        }

        var encoding = String.Encoding.utf8
        return try String(contentsOf: url, usedEncoding: &encoding)
    }
}
