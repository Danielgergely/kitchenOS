//
//  OllamaClient.swift
//  KitchenOS
//
//  Minimal client for a local Ollama server (https://ollama.com), used as the
//  free alternative to Gemini. Only two endpoints are needed:
//  - POST /api/chat  — one non-streamed chat turn, optionally with images,
//                      constrained to a JSON schema via `format`.
//  - GET  /api/tags  — installed models, for the Settings connection test.
//
//  API reference: https://github.com/ollama/ollama/blob/main/docs/api.md
//

import Foundation

enum OllamaError: LocalizedError {
    case invalidServerURL(String)
    case unreachable(String)
    case server(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidServerURL(let url):
            return "“\(url)” isn't a valid Ollama server address. Check Settings → AI Engine."
        case .unreachable(let url):
            return "Couldn't reach Ollama at \(url). Make sure the Mac is awake, Ollama is running, and it accepts network connections (OLLAMA_HOST=0.0.0.0)."
        case .server(let message):
            return "Ollama: \(message)"
        case .emptyResponse:
            return "Ollama returned an empty response."
        }
    }
}

nonisolated struct OllamaClient {
    let baseURL: URL
    let model: String

    /// A fixed context size for every request: changing num_ctx between calls
    /// makes Ollama reload the model. 32k fits a photo, a trimmed web page, or a
    /// recipe catalog of a few hundred entries.
    private static let contextLength = 32_768

    init(serverURL: String, model: String) throws {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host() != nil else {
            throw OllamaError.invalidServerURL(serverURL)
        }
        self.baseURL = url
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The client configured in Settings.
    static func fromSettings() throws -> OllamaClient {
        try OllamaClient(serverURL: OllamaSettings.serverURL, model: OllamaSettings.model)
    }

    /// Sends one user message and returns the model's reply as UTF-8 JSON data,
    /// constrained to `schema`. `images` are JPEG/PNG bytes.
    func chatJSON(prompt: String, images: [Data] = [], schema: [String: Any]) async throws -> Data {
        var message: [String: Any] = ["role": "user", "content": prompt]
        if !images.isEmpty {
            message["images"] = images.map { $0.base64EncodedString() }
        }
        let body: [String: Any] = [
            "model": model,
            "messages": [message],
            "stream": false,
            // Thinking models (e.g. qwen3-vl) otherwise reason at length before
            // answering — minutes instead of seconds. Ignored by other models.
            "think": false,
            "format": schema,
            // Extraction is a transcription task; low temperature keeps
            // amounts and units faithful to the source.
            "options": ["temperature": 0.1, "num_ctx": Self.contextLength],
        ]

        var request = URLRequest(url: baseURL.appending(path: "api/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        // The first request after idle loads the model into memory, which can
        // take a while on top of generation itself.
        request.timeoutInterval = 300

        let data = try await send(request)
        guard let content = try JSONDecoder().decode(ChatResponse.self, from: data).message?.content,
              !content.isEmpty,
              let json = content.data(using: .utf8) else {
            throw OllamaError.emptyResponse
        }
        return json
    }

    /// Names of the models installed on the server, e.g. "qwen3-vl:30b".
    func installedModels() async throws -> [String] {
        var request = URLRequest(url: baseURL.appending(path: "api/tags"))
        request.timeoutInterval = 10
        let data = try await send(request)
        return try JSONDecoder().decode(TagsResponse.self, from: data).models.map(\.name)
    }

    /// Whether `model` is installed; a name without a tag means ":latest", as in Ollama.
    func isModelInstalled(in names: [String]) -> Bool {
        let wanted = model.contains(":") ? model : "\(model):latest"
        return names.contains(wanted)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code != .cancelled {
            throw OllamaError.unreachable(baseURL.absoluteString)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error
            throw OllamaError.server(message ?? "HTTP \(http.statusCode)")
        }
        return data
    }

    // MARK: - Wire types

    private struct ChatResponse: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message?
    }

    private struct TagsResponse: Decodable {
        struct Model: Decodable { let name: String }
        let models: [Model]
    }

    private struct ErrorResponse: Decodable {
        let error: String
    }
}
