//
//  Image+Optimization.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import SwiftUI

extension UIImage {
    /// Resizes the image to a maximum dimension and compresses it to save space.
    func optimizedForDatabase(maxDimension: CGFloat = 1024, compressionQuality: CGFloat = 0.6) -> Data? {
        // 1. Calculate the new size while keeping the aspect ratio
        var newSize = self.size
        if size.width > maxDimension || size.height > maxDimension {
            let aspectRatio = size.width / size.height
            if aspectRatio > 1 {
                newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            }
        }
        
        // 2. Redraw the image at the new smaller size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // Prevents it from scaling up on Retina displays
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        // 3. Convert to JPEG with compression (0.6 is a great balance of size vs quality)
        return resizedImage.jpegData(compressionQuality: compressionQuality)
    }
}
