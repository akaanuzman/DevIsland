import CoreGraphics

/// Original lowercase di monogram. Shared by the vector UI mark and the ICNS generator.
public enum BrandGeometry {
    public static func monogram(in rect: CGRect) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 16, y: 4)); p.addLine(to: CGPoint(x: 21, y: 4))
        p.addLine(to: CGPoint(x: 21, y: 19.5))
        p.addCurve(to: CGPoint(x: 12.5, y: 28), control1: CGPoint(x: 21, y: 24.2), control2: CGPoint(x: 17.2, y: 28))
        p.addCurve(to: CGPoint(x: 4, y: 19.5), control1: CGPoint(x: 7.8, y: 28), control2: CGPoint(x: 4, y: 24.2))
        p.addCurve(to: CGPoint(x: 12.5, y: 11), control1: CGPoint(x: 4, y: 14.8), control2: CGPoint(x: 7.8, y: 11))
        p.addCurve(to: CGPoint(x: 16, y: 11.75), control1: CGPoint(x: 13.8, y: 11), control2: CGPoint(x: 15, y: 11.3))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: 9, y: 16, width: 7, height: 7))
        p.addRoundedRect(in: CGRect(x: 24, y: 14, width: 5, height: 14), cornerWidth: 2.5, cornerHeight: 2.5)
        p.addEllipse(in: CGRect(x: 24, y: 5, width: 5, height: 5))
        var t = CGAffineTransform(scaleX: rect.width / 32, y: rect.height / 32).concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        return p.copy(using: &t)!
    }
}
