#!/usr/bin/env swift
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Deterministic layout only: captured app pixels are placed intact and aspect-fitted.
// Usage: swift marketing/tools/render_campaign.swift [--device all|iphone|ipad]
//        [--manifest path] [--icon path] [--key-art path]
//        [--source-root path] [--output-root path]
// Run from the repository root. There are no runtime package dependencies.

struct Campaign: Decodable {
    let brand: String
    let panels: [Panel]
    let social: SocialCopy
}
struct SocialCopy: Decodable {
    let headline: String
    let subcopy: String
    let footer: String
}
struct Panel: Decodable {
    let id: String
    let eyebrow: String
    let headline: String
    let subcopy: String
    let disclosure: String?
    let appearance: String
}
struct Device {
    let name: String
    let directory: String
    let width: Int
    let height: Int
    static let iphone = Device(name: "iphone", directory: "iphone-6.9", width: 1320, height: 2868)
    static let ipad = Device(name: "ipad", directory: "ipad-13", width: 2064, height: 2752)
}
enum RenderError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let reason) = self { reason } else { "Rendering failed." } }
}

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
let marketing = root.appendingPathComponent("marketing", isDirectory: true)
let arguments = Array(CommandLine.arguments.dropFirst())
func option(_ name: String, default defaultValue: String? = nil) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return defaultValue }
    return arguments[index + 1]
}
func resolve(_ path: String) -> URL {
    path.hasPrefix("/") ? URL(fileURLWithPath: path) : root.appendingPathComponent(path)
}
func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
let pine = color(0x273F36)
let cream = color(0xF5F1E8)
let pale = color(0xFFFCF4)
let gold = color(0xB38745)
let muted = color(0x5D6D61)

func readImage(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw RenderError.invalid("Cannot read image: \(url.path)")
    }
    return image
}
func writePNG(_ image: CGImage, to url: URL) throws {
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw RenderError.invalid("Cannot create PNG: \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyPNGDictionary: [kCGImagePropertyPNGsRGBIntent: 0]] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw RenderError.invalid("PNG export failed: \(url.path)") }
    // The output context has no alpha channel; verify the encoded file instead of assuming it.
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          (properties[kCGImagePropertyPixelWidth] as? Int) == image.width,
          (properties[kCGImagePropertyPixelHeight] as? Int) == image.height,
          (properties[kCGImagePropertyHasAlpha] as? Bool) != true else {
        throw RenderError.invalid("Export verification failed: \(url.path)")
    }
}

func render(width: Int, height: Int, background: NSColor, draw: (CGContext) throws -> Void) throws -> CGImage {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
        throw RenderError.invalid("Cannot allocate \(width) × \(height) RGB canvas")
    }
    context.setFillColor(background.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.interpolationQuality = .high
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    defer { NSGraphicsContext.restoreGraphicsState() }
    try draw(context)
    guard let image = context.makeImage() else { throw RenderError.invalid("Cannot flatten RGB canvas") }
    return image
}

@discardableResult
func text(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat, font: NSFont, color: NSColor,
          tracking: CGFloat = 0, alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 0) -> CGFloat {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = lineSpacing
    let string = NSAttributedString(string: value, attributes: [
        .font: font, .foregroundColor: color, .kern: tracking, .paragraphStyle: paragraph
    ])
    let bounds = string.boundingRect(with: CGSize(width: width, height: 10_000), options: [.usesLineFragmentOrigin, .usesFontLeading])
    string.draw(with: CGRect(x: x, y: y, width: width, height: ceil(bounds.height) + 8),
                options: [.usesLineFragmentOrigin, .usesFontLeading])
    return ceil(bounds.height)
}
func serif(_ size: CGFloat) -> NSFont { NSFont(name: "Baskerville", size: size) ?? NSFont(name: "Georgia", size: size)! }
func sans(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont { NSFont.systemFont(ofSize: size, weight: weight) }
func rounded(_ rect: CGRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill(); path.fill()
    if let stroke { stroke.setStroke(); path.lineWidth = lineWidth; path.stroke() }
}
func drawImage(_ image: CGImage, in rect: CGRect) {
    NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
        .draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
              hints: [.interpolation: NSImageInterpolation.high])
}
func aspectFit(_ image: CGImage, in bounds: CGRect) -> CGRect {
    let factor = min(bounds.width / CGFloat(image.width), bounds.height / CGFloat(image.height))
    let size = CGSize(width: CGFloat(image.width) * factor, height: CGFloat(image.height) * factor)
    return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
}
func aspectFill(_ image: CGImage, in bounds: CGRect, context: CGContext) {
    let factor = max(bounds.width / CGFloat(image.width), bounds.height / CGFloat(image.height))
    let size = CGSize(width: CGFloat(image.width) * factor, height: CGFloat(image.height) * factor)
    context.saveGState(); context.clip(to: bounds)
    drawImage(image, in: CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height))
    context.restoreGState()
}

func deviceFrame(_ image: CGImage, bounds: CGRect, isPad: Bool, dark: Bool, context: CGContext) {
    let border: CGFloat = isPad ? 22 : 18
    let screen = aspectFit(image, in: bounds.insetBy(dx: border, dy: border))
    let frame = screen.insetBy(dx: -border, dy: -border)
    let radius = min(isPad ? 48 : 86, frame.width * 0.09)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 20), blur: 48,
                      color: NSColor.black.withAlphaComponent(dark ? 0.32 : 0.19).cgColor)
    rounded(frame, radius: radius, fill: color(0x222A26))
    context.restoreGState()
    rounded(frame.insetBy(dx: 1, dy: 1), radius: radius - 1, fill: color(0x17221D),
            stroke: color(dark ? 0x819087 : 0xB4B7AB), lineWidth: 2)
    context.saveGState()
    NSBezierPath(roundedRect: screen, xRadius: max(14, radius - border), yRadius: max(14, radius - border)).addClip()
    drawImage(image, in: screen)
    context.restoreGState()
}

func screenshot(_ panel: Panel, index: Int, total: Int, device: Device, capture: CGImage, brand: String) throws -> CGImage {
    let isPad = device.name == "ipad"
    let dark = panel.appearance == "dark"
    let width = CGFloat(device.width), height = CGFloat(device.height)
    let margin = width * 0.082
    let headingColor = dark ? pale : pine
    let secondaryColor = dark ? color(0xD5DDCD) : muted
    let accent = dark ? color(0xD7B579) : gold
    return try render(width: device.width, height: device.height, background: dark ? pine : cream) { context in
        text(panel.eyebrow.uppercased(), x: margin, y: 95, width: width - margin * 2 - 140,
             font: sans(isPad ? 30 : 25, .medium), color: accent, tracking: 3)
        text(String(format: "%02d / %02d", index + 1, total), x: width - margin - 135, y: 96, width: 135,
             font: sans(isPad ? 27 : 23, .regular), color: secondaryColor, tracking: 2, alignment: .right)

        let titleY: CGFloat = isPad ? 169 : 171
        let titleHeight = text(panel.headline, x: margin - 3, y: titleY, width: width - margin * 2,
                               font: serif(isPad ? 184 : 158), color: headingColor, lineSpacing: -4)
        let bodyY = titleY + titleHeight + (isPad ? 26 : 25)
        let bodyHeight = text(panel.subcopy, x: margin + 2, y: bodyY, width: width - margin * 2,
                              font: sans(isPad ? 46 : 40), color: secondaryColor, lineSpacing: isPad ? 8 : 7)

        let captureTop = max(isPad ? 815 : 764, bodyY + bodyHeight + 68)
        let captureBottom = height - (panel.disclosure == nil ? 160 : 197)
        deviceFrame(capture, bounds: CGRect(x: margin - 15, y: captureTop,
                                            width: width - margin * 2 + 30, height: captureBottom - captureTop),
                    isPad: isPad, dark: dark, context: context)

        if let disclosure = panel.disclosure {
            text(disclosure, x: margin, y: height - 139, width: width - margin * 2,
                 font: sans(isPad ? 40 : 36), color: secondaryColor, alignment: .center)
        }
        text(brand.uppercased(), x: margin, y: height - 75, width: width - margin * 2,
             font: sans(isPad ? 28 : 24, .medium), color: headingColor, tracking: isPad ? 8 : 6, alignment: .center)
    }
}

func contactSheet(_ images: [CGImage], device: Device, brand: String) throws -> CGImage {
    let cardWidth: CGFloat = device.name == "iphone" ? 350 : 440
    let cardHeight = cardWidth * CGFloat(device.height) / CGFloat(device.width)
    let gap: CGFloat = 28, margin: CGFloat = 42, header: CGFloat = 96
    let width = Int(margin * 2 + cardWidth * 3 + gap * 2)
    let height = Int(header + cardHeight * 2 + gap + margin)
    return try render(width: width, height: height, background: color(0xE8E5DC)) { _ in
        text("\(brand) / \(device.name == "iphone" ? "iPhone 6.9-inch" : "iPad 13-inch")", x: margin, y: 27,
             width: CGFloat(width) - margin * 2, font: sans(25, .medium), color: pine, tracking: 0.5)
        for (index, image) in images.enumerated() {
            let x = margin + CGFloat(index % 3) * (cardWidth + gap)
            let y = header + CGFloat(index / 3) * (cardHeight + gap)
            drawImage(image, in: CGRect(x: x, y: y, width: cardWidth, height: cardHeight))
        }
    }
}

func social(capture: CGImage, brand: String, copy: SocialCopy, icon: CGImage?, keyArt: CGImage?) throws -> CGImage {
    try render(width: 1600, height: 900, background: pine) { context in
        let artBounds = CGRect(x: 0, y: 0, width: 1600, height: 900)
        if let keyArt { aspectFill(keyArt, in: artBounds, context: context) }
        if let icon {
            let rect = CGRect(x: 88, y: 78, width: 105, height: 105)
            context.saveGState()
            NSBezierPath(roundedRect: rect, xRadius: 24, yRadius: 24).addClip()
            drawImage(icon, in: rect)
            context.restoreGState()
        }
        text(brand, x: icon == nil ? 88 : 220, y: 110, width: 630, font: serif(54), color: pale)
        text(copy.headline, x: 84, y: 270, width: 800, font: serif(109), color: pale, lineSpacing: -4)
        text(copy.subcopy, x: 90, y: 552, width: 805,
             font: sans(29), color: color(0xD5DDCD), lineSpacing: 8)
        text(copy.footer.uppercased(), x: 91, y: 770, width: 720, font: sans(22, .medium), color: color(0xD7B579), tracking: 4)
        deviceFrame(capture, bounds: CGRect(x: 1038, y: 62, width: 490, height: 775), isPad: false, dark: true, context: context)
    }
}

do {
    if arguments.contains("--help") {
        print("Usage: swift marketing/tools/render_campaign.swift [--device all|iphone|ipad] [--manifest path] [--icon path] [--key-art path] [--source-root path] [--output-root path]")
        exit(0)
    }
    let campaign = try JSONDecoder().decode(Campaign.self, from: Data(contentsOf: resolve(option("--manifest", default: "marketing/campaign.en-US.json")!)))
    guard campaign.panels.count == 6, Set(campaign.panels.map(\.id)).count == 6 else {
        throw RenderError.invalid("Campaign manifest must contain six uniquely named panels")
    }
    let choice = option("--device", default: "all")!
    guard ["all", "iphone", "ipad"].contains(choice) else { throw RenderError.invalid("--device must be all, iphone, or ipad") }
    let devices = [Device.iphone, Device.ipad].filter { choice == "all" || $0.name == choice }
    let sourceRoot = resolve(option("--source-root", default: "marketing/source-captures")!)
    let outputRoot = resolve(option("--output-root", default: "marketing")!)
    // Validate every requested capture before writing any exports. Missing screens are never fabricated.
    var captures: [String: [CGImage]] = [:]
    for device in devices {
        captures[device.name] = try campaign.panels.map {
            try readImage(sourceRoot.appendingPathComponent("\(device.name)/\($0.id).png"))
        }
    }
    for device in devices {
        var images: [CGImage] = []
        for (index, panel) in campaign.panels.enumerated() {
            let image = try screenshot(panel, index: index, total: campaign.panels.count, device: device,
                                       capture: captures[device.name]![index], brand: campaign.brand)
            let output = outputRoot.appendingPathComponent("exports/\(device.directory)/\(panel.id).png")
            try writePNG(image, to: output)
            images.append(image)
            print("Exported \(output.path) [\(image.width) × \(image.height), RGB, no alpha]")
        }
        let sheet = try contactSheet(images, device: device, brand: campaign.brand)
        try writePNG(sheet, to: outputRoot.appendingPathComponent("previews/contact-\(device.name).png"))
    }
    if let phone = captures["iphone"]?.first {
        let iconPath = option("--icon", default: "marketing/icons/Marblezzz-AppIcon-1024.png")!
        let icon = fileManager.fileExists(atPath: resolve(iconPath).path) ? try readImage(resolve(iconPath)) : nil
        let keyArt = try option("--key-art").map { try readImage(resolve($0)) }
        let banner = try social(capture: phone, brand: campaign.brand, copy: campaign.social, icon: icon, keyArt: keyArt)
        try writePNG(banner, to: outputRoot.appendingPathComponent("exports/social-1600x900.png"))
    }
    print("Campaign rendering complete.")
} catch {
    fputs("Campaign error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
