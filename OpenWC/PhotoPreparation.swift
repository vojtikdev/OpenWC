import UIKit
import ImageIO

@MainActor
enum PhotoPreparation {
    static func avatar(_ data: Data) throws -> Data {
        guard data.count <= 25_000_000 else { throw AppError.message("Choose a photo smaller than 25 MB.") }
        let options: CFDictionary = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024
              ] as CFDictionary) else { throw AppError.message("This photo couldn’t be opened. Try a JPEG or HEIC image.") }
        let image = UIImage(cgImage: thumbnail)
        let side: CGFloat = 512
        let factor = max(side / image.size.width, side / image.size.height)
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let cropped = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.systemBackground.setFill(); context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            image.draw(in: CGRect(x: (side-size.width)/2, y: (side-size.height)/2, width: size.width, height: size.height))
        }
        guard let result = cropped.jpegData(compressionQuality: 0.82), result.count <= 1_000_000 else { throw AppError.message("This photo is too large. Try another image.") }
        return result
    }
}
