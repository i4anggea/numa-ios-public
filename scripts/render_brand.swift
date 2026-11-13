// Rebuild the temporary Numa logo using system frameworks, without dependencies.
// Run from the project root: swift scripts/render_brand.swift
import AppKit
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let rect = CGRect(x: 0, y: 0, width: size, height: size)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                              bytesPerRow: size * 4, space: space,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("No se pudo crear el lienzo del icono")
}
context.setFillColor(CGColor(red: 0.07, green: 0.24, blue: 0.47, alpha: 1))
context.fill(rect)
context.translateBy(x: 0, y: CGFloat(size))
context.scaleBy(x: 1, y: -1)
context.setStrokeColor(CGColor(gray: 1, alpha: 1))
context.setLineWidth(CGFloat(size) * 0.10)
context.setLineCap(.round)
context.setLineJoin(.round)
context.move(to: CGPoint(x: 1024 * 0.28, y: 1024 * 0.70))
context.addLine(to: CGPoint(x: 1024 * 0.28, y: 1024 * 0.30))
context.addLine(to: CGPoint(x: 1024 * 0.72, y: 1024 * 0.70))
context.addLine(to: CGPoint(x: 1024 * 0.72, y: 1024 * 0.30))
context.strokePath()
guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: "Assets/Numa.xcassets/AppIcon.appiconset/Numa.png") as CFURL,
        UTType.png.identifier as CFString, 1, nil) else { fatalError("No se pudo crear el PNG") }
CGImageDestinationAddImage(destination, image, nil)
precondition(CGImageDestinationFinalize(destination), "No se pudo guardar el PNG")
print("Icono Numa regenerado: 1024 × 1024, opaco")
