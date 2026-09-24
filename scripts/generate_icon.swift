import AppKit
import Foundation

let destination = CommandLine.arguments[1]
let size = CGSize(width: 1024, height: 1024)
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
NSColor(calibratedRed: 0.13, green: 0.23, blue: 0.19, alpha: 1).setFill()
NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
let board = NSBezierPath(roundedRect: CGRect(x: 108,y: 108,width: 808,height: 808), xRadius: 105,yRadius: 105)
NSGradient(starting: NSColor(calibratedRed: 0.91,green: 0.76,blue: 0.53,alpha: 1), ending: NSColor(calibratedRed: 0.69,green: 0.47,blue: 0.26,alpha: 1))!.draw(in: board, angle: -30)
NSColor.white.withAlphaComponent(0.2).setStroke(); board.lineWidth = 5; board.stroke()
for row in 0..<52 {
    let y = 120 + CGFloat(row)*15
    let line = NSBezierPath(); line.move(to: CGPoint(x: 143,y: y)); line.curve(to: CGPoint(x: 882,y: y+9), controlPoint1: CGPoint(x: 360,y: y-10), controlPoint2: CGPoint(x: 630,y: y+19))
    NSColor.brown.withAlphaComponent(0.11).setStroke(); line.lineWidth = 2; line.stroke()
}
let colors = [NSColor(calibratedRed: 0.76,green: 0.19,blue: 0.23,alpha: 1), NSColor(calibratedRed: 0.96,green: 0.72,blue: 0.13,alpha: 1), NSColor(calibratedRed: 0.16,green: 0.52,blue: 0.32,alpha: 1), NSColor(calibratedRed: 0.18,green: 0.42,blue: 0.76,alpha: 1)]
for i in 0..<5 {
    let points = [CGPoint(x: 242+CGFloat(i)*45,y: 512), CGPoint(x: 512,y: 782-CGFloat(i)*45), CGPoint(x: 782-CGFloat(i)*45,y: 512), CGPoint(x: 512,y: 242+CGFloat(i)*45)]
    for (index,p) in points.enumerated() {
        colors[index].withAlphaComponent(0.8).setFill(); NSBezierPath(ovalIn: CGRect(x: p.x-13,y: p.y-13,width: 26,height: 26)).fill()
    }
}
let marbles = [CGPoint(x: 298,y: 708),CGPoint(x: 708,y: 708),CGPoint(x: 708,y: 298),CGPoint(x: 298,y: 298)]
for (index,point) in marbles.enumerated() {
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.4); shadow.shadowBlurRadius = 14; shadow.shadowOffset = CGSize(width: 0,height: -14)
    NSGraphicsContext.saveGraphicsState(); shadow.set()
    let sphere = NSBezierPath(ovalIn: CGRect(x: point.x-98,y: point.y-98,width: 196,height: 196))
    colors[index].setFill(); sphere.fill(); NSGraphicsContext.restoreGraphicsState()
    NSGradient(colorsAndLocations: (NSColor.white,0), (colors[index],0.32), (NSColor.black,1))!.draw(in: sphere, relativeCenterPosition: NSPoint(x: -0.35,y: 0.4))
    NSColor.white.withAlphaComponent(0.72).setFill()
    NSBezierPath(ovalIn: CGRect(x: point.x-49,y: point.y+34,width: 54,height: 23)).fill()
}
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
