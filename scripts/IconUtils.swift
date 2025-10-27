import AppKit
import Foundation

/// Shared utilities for icon generation scripts
struct IconUtils {

    /// Creates a bitmap CGContext with the specified pixel size
    static func createBitmapContext(pixelSize: Int) -> CGContext? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        return CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: 4 * pixelSize,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
    }

    /// Configuration for rendering a symbol
    struct SymbolRenderConfig {
        let symbolName: String
        let pixelSize: Int
        let sizeRatio: CGFloat  // Symbol size as a ratio of pixelSize (e.g., 0.6 = 60%)
        let weight: NSFont.Weight
        let color: NSColor

        init(symbolName: String, pixelSize: Int, sizeRatio: CGFloat = 0.6, weight: NSFont.Weight = .regular, color: NSColor = .white) {
            self.symbolName = symbolName
            self.pixelSize = pixelSize
            self.sizeRatio = sizeRatio
            self.weight = weight
            self.color = color
        }
    }

    /// Renders an SF Symbol into the given CGContext
    /// - Parameters:
    ///   - context: The CGContext to draw into
    ///   - config: Configuration for the symbol rendering
    /// - Returns: true if successful, false otherwise
    @discardableResult
    static func renderSymbol(into context: CGContext, config: SymbolRenderConfig) -> Bool {
        let symbolSize = CGFloat(config.pixelSize) * config.sizeRatio
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: config.weight)

        guard let symbol = NSImage(systemSymbolName: config.symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfig) else {
            return false
        }

        // Create NSGraphicsContext from CGContext
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext

        // Set color and draw symbol centered
        config.color.set()

        let symbolRect = NSRect(
            x: (CGFloat(config.pixelSize) - symbol.size.width) / 2,
            y: (CGFloat(config.pixelSize) - symbol.size.height) / 2,
            width: symbol.size.width,
            height: symbol.size.height
        )

        symbol.draw(in: symbolRect)
        return true
    }

    /// Saves a CGContext as a PNG file
    /// - Parameters:
    ///   - context: The context to save
    ///   - outputPath: File path to write the PNG
    ///   - pixelSize: The pixel dimensions of the image
    /// - Returns: true if successful, false otherwise
    @discardableResult
    static func saveToPNG(context: CGContext, outputPath: String, pixelSize: Int) -> Bool {
        guard let cgImage = context.makeImage() else {
            return false
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        bitmapRep.size = NSSize(width: pixelSize, height: pixelSize)

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return false
        }

        do {
            try pngData.write(to: URL(fileURLWithPath: outputPath))
            print("✅ Generated: \(outputPath) (\(pixelSize)x\(pixelSize) pixels)")
            return true
        } catch {
            print("❌ Failed to write: \(outputPath) - \(error)")
            return false
        }
    }
}
