// Generate menubar icon from SF Symbol
// Menubar icons are template images (monochrome, rendered in system color)
// NOTE: This file is meant to be run with IconUtils.swift: swift IconUtils.swift generate_menubar_icon.swift

import AppKit
import Foundation

func generateMenuBarIcon(symbolName: String, outputPath: String, pixelSize: Int) {
    // Create bitmap context
    guard let context = IconUtils.createBitmapContext(pixelSize: pixelSize) else {
        print("Failed to create context for \(outputPath)")
        return
    }

    // Configure symbol rendering (black for template images, 0.8 size ratio, medium weight)
    let config = IconUtils.SymbolRenderConfig(
        symbolName: symbolName,
        pixelSize: pixelSize,
        sizeRatio: 0.8,
        weight: .medium,
        color: .black
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
struct MenuBarIconGenerator {
    static func main() {
        let outputDir = "WigiAI/Assets.xcassets/MenuBarIcon.imageset"

        print("🎨 Generating menubar icons...")
        print("")

        // Menubar icons need to be simple and monochrome
        // 16x16 for 1x displays, 32x32 for 2x (Retina)
        generateMenuBarIcon(
            symbolName: "character.bubble.fill",
            outputPath: "\(outputDir)/menubar_icon_16.png",
            pixelSize: 16
        )

        generateMenuBarIcon(
            symbolName: "character.bubble.fill",
            outputPath: "\(outputDir)/menubar_icon_32.png",
            pixelSize: 32
        )

        print("")
        print("✅ Menubar icons generated!")
        print("")
        print("These are template images - macOS will render them in the menubar color.")
    }
}
