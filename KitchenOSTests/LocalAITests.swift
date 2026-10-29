//
//  LocalAITests.swift
//  KitchenOSTests
//
//  Tests for the local (Ollama) AI path: trimming web pages down to text and
//  the client's configuration helpers. No server is contacted.
//

import Testing
@testable import KitchenOS

struct LocalAITests {

    // MARK: - WebPageText

    @Test func stripsScriptsStylesAndMarkup() {
        let html = """
        <html><head><title>T</title><style>.a{color:red}</style></head>
        <body><script>var x = 1;</script>
        <h1>Pancakes</h1><ul><li>200 g flour</li><li>2 eggs</li></ul>
        <p>Mix &amp; fry.</p></body></html>
        """
        let text = WebPageText.readableText(fromHTML: html)
        #expect(text == "Pancakes\n200 g flour\n2 eggs\nMix & fry.")
    }

    @Test func keepsOgImageAsFirstLine() {
        let html = """
        <head><meta content="https://example.com/p.jpg" property="og:image"></head>
        <body><p>Soup</p></body>
        """
        let text = WebPageText.readableText(fromHTML: html)
        #expect(text.hasPrefix("og:image: https://example.com/p.jpg\n"))
        #expect(text.hasSuffix("Soup"))
    }

    @Test func capsLength() {
        let html = "<p>" + String(repeating: "a", count: 500) + "</p>"
        #expect(WebPageText.readableText(fromHTML: html, limit: 100).count == 100)
    }

    // MARK: - OllamaClient

    @Test func rejectsInvalidServerURL() {
        #expect(throws: OllamaError.self) { try OllamaClient(serverURL: "my mac", model: "m") }
    }

    @Test func untaggedModelMeansLatest() throws {
        let client = try OllamaClient(serverURL: "http://mac.local:11434", model: "gemma3")
        #expect(client.isModelInstalled(in: ["gemma3:latest"]))
        #expect(!client.isModelInstalled(in: ["gemma3:27b"]))
    }

    @Test func taggedModelMatchesExactly() throws {
        let client = try OllamaClient(serverURL: "http://mac.local:11434", model: " qwen3-vl:30b ")
        #expect(client.isModelInstalled(in: ["qwen3-vl:30b"]))
        #expect(!client.isModelInstalled(in: ["qwen3-vl:8b"]))
    }
}
