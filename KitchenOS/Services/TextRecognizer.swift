//
//  TextRecognizer.swift
//  KitchenOS
//
//  Reads the text in a photo with Apple's Vision framework. Runs on every
//  device, offline and for free — the first step of on-device recipe import,
//  whether the text then goes to Apple's on-device model or RecipeTextParser.
//

import UIKit
import Vision

nonisolated enum TextRecognizer {

    enum RecognitionError: LocalizedError {
        case unreadableImage
        case noText

        var errorDescription: String? {
            switch self {
            case .unreadableImage: return "Couldn't read the photo."
            case .noText: return "No text was found in the photo. Try a sharper, well-lit picture of the recipe."
            }
        }
    }

    /// The photo's lines of text in reading order.
    static func lines(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw RecognitionError.unreadableImage }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let observations = try await request.perform(on: cgImage, orientation: orientation(of: image))
        let lines = observations
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { throw RecognitionError.noText }
        return lines
    }

    /// Camera photos are stored sideways with an orientation flag; Vision needs
    /// that flag to read them upright.
    private static func orientation(of image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
