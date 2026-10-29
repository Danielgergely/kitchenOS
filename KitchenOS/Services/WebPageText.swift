//
//  WebPageText.swift
//  KitchenOS
//
//  Reduces a web page to the text a local model actually needs. Gemini can take
//  a whole raw HTML page, but a local model's context is far smaller and raw
//  markup is mostly scripts, styles and navigation, so pages without JSON-LD
//  are trimmed down to their visible text before extraction.
//

import Foundation

// `nonisolated`: regexing a whole page is pure computation and must not run on
// the main actor, which the file's default isolation would impose.
nonisolated enum WebPageText {

    /// The page's visible text, capped at `limit` characters. The og:image URL,
    /// if any, is kept as a first line so the model can still report the cover
    /// image even though the markup is gone.
    static func readableText(fromHTML html: String, limit: Int = 40_000) -> String {
        var text = html
        for element in ["script", "style", "noscript", "svg", "head", "nav", "footer"] {
            text = text.replacingOccurrences(
                of: "<\(element)\\b[^>]*>.*?</\(element)>",
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        // Block-level tags become line breaks so lists and steps stay readable.
        text = text.replacingOccurrences(
            of: "<(br|/p|/li|/h[1-6]|/div|/tr)\\b[^>]*>",
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
                        "&#39;": "'", "&apos;": "'", "&nbsp;": " "]
        for (entity, char) in entities {
            text = text.replacingOccurrences(of: entity, with: char)
        }

        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s*\\n\\s*", with: "\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let image = ogImageURL(in: html) {
            text = "og:image: \(image)\n\n" + text
        }
        return String(text.prefix(limit))
    }

    static func ogImageURL(in html: String) -> String? {
        // Attribute order varies between sites, so match the tag first, then read content.
        guard let tag = html.range(
            of: "<meta[^>]+property=[\"']og:image[\"'][^>]*>",
            options: [.regularExpression, .caseInsensitive]
        ) else { return nil }
        let meta = String(html[tag])
        guard let content = meta.range(
            of: "content=[\"'][^\"']+[\"']",
            options: [.regularExpression, .caseInsensitive]
        ) else { return nil }
        return String(meta[content].dropFirst("content=\"".count).dropLast())
    }
}
