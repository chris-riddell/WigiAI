// Generate app icon from SF Symbol with exact pixel dimensions
// NOTE: This file is meant to be run with IconUtils.swift: swift IconUtils.swift generate_icon.swift

import AppKit
import Foundation

func generateIcon(symbolName: String, outputPath: String, pixelSize: Int) {
    // Create bitmap context
    guard let context = IconUtils.createBitmapContext(pixelSize: pixelSize) else {
        print("Failed to create context for \(outputPath)")
        return
    }

    // Save graphics state before drawing background
    context.saveGState()

    // Create gradient background (blue to purple)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0),
        CGColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 1.0)
    ] as CFArray

    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0])!

    // Draw rounded rectangle with gradient
    let rect = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    let cornerRadius = CGFloat(pixelSize) * 0.2
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    context.addPath(path)
    context.clip()

    // Draw gradient
    let startPoint = CGPoint(x: 0, y: CGFloat(pixelSize))
    let endPoint = CGPoint(x: CGFloat(pixelSize), y: 0)
    context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])

    context.restoreGState()

    // Configure symbol rendering (white color, 0.6 size ratio, regular weight)
    let config = IconUtils.SymbolRenderConfig(
        symbolName: symbolName,
        pixelSize: pixelSize,
        sizeRatio: 0.6,
        weight: .regular,
        color: .white
    )

    // Render symbol and save
    if IconUtils.renderSymbol(into: context, config: config) {
        IconUtils.saveToPNG(context: context, outputPath: outputPath, pixelSize: pixelSize)
    } else {
        print("Failed to render symbol for \(outputPath)")
    }
}

// Main entry point
@main
struct AppIconGenerator {
    static func main() {
        let outputDir = "WigiAI/Assets.xcassets/AppIcon.appiconset"

        // Map of filename to exact pixel dimensions needed
        let iconSizes: [(String, Int)] = [
            ("icon_16x16.png", 16),           // 16x16 @1x
            ("icon_16x16@2x.png", 32),        // 16x16 @2x = 32px
            ("icon_32x32.png", 32),           // 32x32 @1x
            ("icon_32x32@2x.png", 64),        // 32x32 @2x = 64px
            ("icon_128x128.png", 128),        // 128x128 @1x
            ("icon_128x128@2x.png", 256),     // 128x128 @2x = 256px
            ("icon_256x256.png", 256),        // 256x256 @1x
            ("icon_256x256@2x.png", 512),     // 256x256 @2x = 512px
            ("icon_512x512.png", 512),        // 512x512 @1x
            ("icon_512x512@2x.png", 1024)     // 512x512 @2x = 1024px
        ]

        print("🎨 Generating app icons with exact pixel dimensions...")
        print("")

        for (filename, pixelSize) in iconSizes {
            let path = "\(outputDir)/\(filename)"
            generateIcon(symbolName: "character.bubble.fill", outputPath: path, pixelSize: pixelSize)
        }

        print("")
        print("✅ All icon sizes generated with correct dimensions!")
        print("")
        print("Verify with: sips -g pixelWidth -g pixelHeight \(outputDir)/*.png")
    }
}
