// Renders the Zip Flip app icon: two cards, the top one caught mid-turn,
// dark on the teal field. One 1024 px PNG without an alpha channel, used
// unchanged by both targets (App Review rejects mismatched icons).
//
//   swift tools/makeicon.swift ZipFlip/Assets.xcassets/AppIcon.appiconset/icon.png
//   cp ZipFlip/Assets.xcassets/AppIcon.appiconset/icon.png ZipFlipContainer/Assets.xcassets/AppIcon.appiconset/icon.png
//
// Geometry is in a 100-unit box, the same numbers as the design canvas and
// FlipGlyph in Design.swift. watchOS masks the icon to a circle, so nothing
// important sits in the corners.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let unit = CGFloat(size) / 100

func rgb(_ r: Int, _ g: Int, _ b: Int) -> CGColor {
    CGColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
}
let field = rgb(0x6E, 0xB6, 0xCF)
let glyph = rgb(0x14, 0x14, 0x13)

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: makeicon.swift <output.png>\n".utf8))
    exit(2)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])

let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    FileHandle.standardError.write(Data("could not create bitmap context\n".utf8))
    exit(1)
}

// Work in the 100-unit, y-down coordinate system of the design.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: unit, y: -unit)
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

ctx.setFillColor(field)
ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))

func card(_ rect: CGRect) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: 7, cornerHeight: 7, transform: nil)
}

// Bottom card, flat.
ctx.setFillColor(glyph)
ctx.addPath(card(CGRect(x: 24, y: 36, width: 52, height: 38)))
ctx.fillPath()

// Top card, rotated 14 degrees about (50, 46), outlined in the field colour
// so the two cards stay separate.
ctx.saveGState()
ctx.translateBy(x: 50, y: 46)
ctx.rotate(by: -14 * .pi / 180)
ctx.translateBy(x: -50, y: -46)
let top = card(CGRect(x: 24, y: 27, width: 52, height: 38))
ctx.setFillColor(glyph)
ctx.addPath(top)
ctx.fillPath()
ctx.setStrokeColor(field)
ctx.setLineWidth(4)
ctx.addPath(top)
ctx.strokePath()
ctx.restoreGState()

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    FileHandle.standardError.write(Data("could not create image\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write(Data("could not write \(output.path)\n".utf8))
    exit(1)
}
print("wrote \(output.path) (\(size)x\(size), no alpha)")
