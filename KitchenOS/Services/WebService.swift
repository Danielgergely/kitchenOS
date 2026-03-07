//
//  WebService.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/7/26.
//

import Foundation

class WebService {
    
    static func downloadImage(from url: URL) async -> Data? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            print("Failed to download image from URL: \(error.localizedDescription)")
            return nil
        }
    }
}
