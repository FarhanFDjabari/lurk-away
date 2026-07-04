import AppKit
import CoreGraphics
import UniformTypeIdentifiers

let green = CGColor(red: 0.243, green: 0.608, blue: 0.522, alpha: 1)   // #3E9B85
let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

func ctx(_ s: Int) -> CGContext {
    CGContext(data: nil, width: s, height: s, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func draw(size: Int, template: Bool) -> CGImage {
    let S = CGFloat(size)
    let c = ctx(size)
    c.setAllowsAntialiasing(true)
    c.interpolationQuality = .high

    func rectC(_ cx: CGFloat, _ cyTop: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        let ww: CGFloat = w * S
        let hh: CGFloat = h * S
        let ox: CGFloat = cx * S - ww / 2
        let oy: CGFloat = (1 - cyTop) * S - hh / 2
        return CGRect(x: ox, y: oy, width: ww, height: hh)
    }
    func circ(_ cx: CGFloat, _ cyTop: CGFloat, _ r: CGFloat) -> CGRect {
        let d: CGFloat = r * 2 * S
        let ox: CGFloat = cx * S - r * S
        let oy: CGFloat = (1 - cyTop) * S - r * S
        return CGRect(x: ox, y: oy, width: d, height: d)
    }

    // Background
    if !template {
        let bg = CGPath(roundedRect: CGRect(x: 0, y: 0, width: S, height: S),
                        cornerWidth: 0.2237 * S, cornerHeight: 0.2237 * S, transform: nil)
        c.addPath(bg); c.setFillColor(green); c.fillPath()
    } else {
        // Menu bar: no background, so scale the glyph up to fill the canvas for legibility.
        let k: CGFloat = 1.4
        c.translateBy(x: S / 2, y: S / 2)
        c.scaleBy(x: k, y: k)
        c.translateBy(x: -S / 2, y: -S / 2)
    }

    // Single bold eye (almond) with a keyhole pupil: "watching" + "secure".
    let darkIris = CGColor(red: 0.086, green: 0.278, blue: 0.235, alpha: 1)   // deep teal
    func pt(_ fx: CGFloat, _ fyTop: CGFloat) -> CGPoint { CGPoint(x: fx * S, y: (1 - fyTop) * S) }

    func keyholePath() -> CGPath {
        let p = CGMutablePath()
        p.addEllipse(in: circ(0.5, 0.455, 0.07))
        p.addRect(rectC(0.5, 0.57, 0.052, 0.12))
        return p
    }

    let eye = CGMutablePath()
    eye.move(to: pt(0.13, 0.5))
    eye.addQuadCurve(to: pt(0.87, 0.5), control: pt(0.5, 0.18))   // upper lid
    eye.addQuadCurve(to: pt(0.13, 0.5), control: pt(0.5, 0.82))   // lower lid

    if template {
        // Eye outline + big pupil with the keyhole punched out.
        c.setStrokeColor(white)
        c.setLineWidth(0.055 * S)
        c.setLineJoin(.round)
        c.addPath(eye); c.strokePath()
        c.setFillColor(white); c.addEllipse(in: circ(0.5, 0.5, 0.17)); c.fillPath()
        c.setBlendMode(.clear); c.addPath(keyholePath()); c.fillPath(); c.setBlendMode(.normal)
    } else {
        c.setFillColor(white); c.addPath(eye); c.fillPath()                       // sclera
        c.setFillColor(darkIris); c.addEllipse(in: circ(0.5, 0.5, 0.2)); c.fillPath()  // iris
        c.setFillColor(white); c.addPath(keyholePath()); c.fillPath()             // keyhole pupil
        c.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
        c.addEllipse(in: circ(0.4, 0.42, 0.028)); c.fillPath()                    // highlight
    }

    return c.makeImage()!
}

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : "."
let mode = args.count > 2 ? args[2] : "preview"

if mode == "preview" {
    writePNG(draw(size: 256, template: false), to: "\(outDir)/preview_icon.png")
    // Composite glyph on gray so template (white) is visible; big + small.
    let big = 128
    let g = ctx(big)
    g.setFillColor(CGColor(red: 0.25, green: 0.25, blue: 0.27, alpha: 1))
    g.fill(CGRect(x: 0, y: 0, width: big, height: big))
    g.draw(draw(size: big, template: true), in: CGRect(x: 0, y: 0, width: big, height: big))
    // simulate menu bar 18px scaled up for inspection
    g.draw(draw(size: 18, template: true), in: CGRect(x: big-40, y: 4, width: 36, height: 36))
    writePNG(g.makeImage()!, to: "\(outDir)/preview_glyph.png")
    print("preview written")
} else {
    // App icon sizes
    for px in [16, 32, 64, 128, 256, 512, 1024] {
        writePNG(draw(size: px, template: false), to: "\(outDir)/appicon_\(px).png")
    }
    // Menu bar template
    writePNG(draw(size: 18, template: true), to: "\(outDir)/glyph_18.png")
    writePNG(draw(size: 36, template: true), to: "\(outDir)/glyph_36.png")
    writePNG(draw(size: 54, template: true), to: "\(outDir)/glyph_54.png")
    print("all written")
}
