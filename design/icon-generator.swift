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
    }

    // Eyes (white ellipses, slight outward tilt)
    let eyeW: CGFloat = 0.25, eyeH: CGFloat = 0.42
    let eyes: [(x: CGFloat, tilt: CGFloat)] = [(0.35, 12), (0.65, -12)]
    let eyeCyTop: CGFloat = 0.45
    c.setFillColor(white)
    for e in eyes {
        c.saveGState()
        let cx = e.x * S, cy = (1 - eyeCyTop) * S
        c.translateBy(x: cx, y: cy)
        c.rotate(by: e.tilt * .pi / 180)
        c.addEllipse(in: CGRect(x: -eyeW * S / 2, y: -eyeH * S / 2, width: eyeW * S, height: eyeH * S))
        c.fillPath()
        c.restoreGState()
    }

    // Pupils — looking down. Green (icon) or punched (template).
    let pupilR: CGFloat = 0.092
    for e in eyes {
        let dir: CGFloat = e.x < 0.5 ? -1 : 1
        let px: CGFloat = e.x + dir * 0.02
        let pyTop: CGFloat = eyeCyTop + 0.13
        let r = circ(px, pyTop, pupilR)
        if template {
            c.setBlendMode(.clear); c.addEllipse(in: r); c.fillPath(); c.setBlendMode(.normal)
        } else {
            c.setFillColor(green); c.addEllipse(in: r); c.fillPath()
            c.setFillColor(white); c.addEllipse(in: circ(px + dir * 0.015, pyTop - 0.04, 0.024)); c.fillPath()
        }
    }

    // Padlock (white). Shackle first, then body, then keyhole.
    c.setFillColor(white); c.setStrokeColor(white)
    let lockCx: CGFloat = 0.5
    let shackleR: CGFloat = 0.075
    let shackleCyTop: CGFloat = 0.6
    c.setLineWidth(0.052 * S)
    c.setLineCap(.round)
    let scx = lockCx * S, scy = (1 - shackleCyTop) * S
    c.addArc(center: CGPoint(x: scx, y: scy), radius: shackleR * S,
             startAngle: 0, endAngle: .pi, clockwise: false)
    c.strokePath()

    // Body
    let body = CGPath(roundedRect: rectC(lockCx, 0.725, 0.27, 0.225),
                      cornerWidth: 0.05 * S, cornerHeight: 0.05 * S, transform: nil)
    c.addPath(body); c.setFillColor(white); c.fillPath()

    // Keyhole
    let khCyTop: CGFloat = 0.7
    if template {
        c.setBlendMode(.clear)
        c.addEllipse(in: circ(lockCx, khCyTop, 0.032)); c.fillPath()
        c.addPath(CGPath(rect: rectC(lockCx, khCyTop + 0.045, 0.028, 0.06), transform: nil)); c.fillPath()
        c.setBlendMode(.normal)
    } else {
        c.setFillColor(green)
        c.addEllipse(in: circ(lockCx, khCyTop, 0.032)); c.fillPath()
        c.addPath(CGPath(rect: rectC(lockCx, khCyTop + 0.045, 0.028, 0.06), transform: nil)); c.fillPath()
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
