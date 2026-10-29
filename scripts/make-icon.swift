import AppKit
import Foundation

@main struct IconGenerator {
    static func main() throws {
        let output = CommandLine.arguments[1]
        let image = NSImage(size: NSSize(width: 1024, height: 1024))
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        context.translateBy(x: 0, y: 1024); context.scaleBy(x: 1, y: -1)
        let tile = CGPath(roundedRect: CGRect(x: 54, y: 54, width: 916, height: 916), cornerWidth: 204, cornerHeight: 204, transform: nil)
        context.setFillColor(NSColor(srgbRed: 217/255, green: 119/255, blue: 87/255, alpha: 1).cgColor)
        context.addPath(tile); context.fillPath()
        context.addPath(BrandGeometry.monogram(in: CGRect(x: 160, y: 160, width: 704, height: 704)))
        context.setFillColor(NSColor(srgbRed: 1, green: 0.97, blue: 0.93, alpha: 1).cgColor)
        context.drawPath(using: .eoFill)
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
    }
}
