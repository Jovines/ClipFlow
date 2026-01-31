import Cocoa

enum ImageOptimizer {
    static let thumbnailSize = CGSize(width: 120, height: 120)
    static let maxImageDimension: CGFloat = 2048
    static let thumbnailCompressionQuality: CGFloat = 0.7
    static let fullCompressionQuality: CGFloat = 0.85

    static func compressImage(_ nsImage: NSImage, quality: CGFloat = fullCompressionQuality) -> Data? {
        let resizedImage = resizeIfNeeded(nsImage)
        guard let resizedTiff = resizedImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: resizedTiff) else { return nil }
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    static func generateThumbnail(from nsImage: NSImage) -> Data? {
        let thumbnail = nsImage.resized(to: thumbnailSize)
        guard let tiff = thumbnail.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: thumbnailCompressionQuality])
    }

    private static func resizeIfNeeded(_ image: NSImage) -> NSImage {
        let size = image.size
        guard size.width > maxImageDimension || size.height > maxImageDimension else { return image }
        let scale = min(maxImageDimension / size.width, maxImageDimension / size.height)
        return image.resized(to: CGSize(width: size.width * scale, height: size.height * scale))
    }
}

extension NSImage {
    func resized(to newSize: CGSize) -> NSImage {
        let image = NSImage(size: newSize)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: CGRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
        image.unlockFocus()
        return image
    }
}
