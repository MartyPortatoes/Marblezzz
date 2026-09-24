import SpriteKit
import UIKit
import MarblezzzCore

@MainActor final class MarbleBoardScene: SKScene {
    var onMarbleTap: ((Int) -> Void)?
    private var currentMarbles: [Marble] = Marble.initial
    private var theme: BoardTheme = .original
    private var initialized = false
    private var selectedIDs = Set<Int>()
    private var preview: MovePreview?
    private var previewOwner: Seat = .red
    private var motionReduced = false
    private var boardLayer = SKNode()
    private var marbleLayer = SKNode()
    private var highlightLayer = SKNode()
    private var marbleNodes: [Int: SKNode] = [:]
    private var textures: [String: SKTexture] = [:]
    private var renderRequested = true

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill; backgroundColor = .clear
        addChild(boardLayer); addChild(highlightLayer); addChild(marbleLayer)
        boardLayer.zPosition = 0; highlightLayer.zPosition = 2; marbleLayer.zPosition = 3
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    private var step: CGFloat { min(size.width, size.height) / 14.5 }
    private func location(_ point: BoardPoint) -> CGPoint {
        CGPoint(x: size.width/2 + CGFloat(point.x - 6) * step, y: size.height/2 - CGFloat(point.y - 6) * step)
    }
    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        rebuildBoard(); drawMarbles(animated: false); drawHighlights()
        renderRequested = true
    }
    /// Static canvases render after content or geometry changes, then skip unchanged frames.
    func consumeRenderRequest() -> Bool {
        defer { renderRequested = false }
        return renderRequested
    }
    func configure(marbles: [Marble], theme: BoardTheme, highlighted: Set<Int> = [], preview: MovePreview? = nil,
                   previewOwner: Seat = .red, reduceMotion: Bool = false) {
        let rebuild = !initialized || self.theme != theme
        self.theme = theme; self.selectedIDs = highlighted; self.preview = preview
        self.previewOwner = previewOwner; self.motionReduced = reduceMotion
        currentMarbles = marbles
        if rebuild { textures = [:]; rebuildBoard(); initialized = true }
        drawMarbles(animated: !rebuild && !reduceMotion); drawHighlights()
        renderRequested = true
    }
    private func rebuildBoard() {
        boardLayer.removeAllChildren()
        let side = min(size.width, size.height) - 4
        let board = SKSpriteNode(texture: woodTexture(), size: CGSize(width: side, height: side))
        board.position = CGPoint(x: size.width/2, y: size.height/2)
        boardLayer.addChild(board)
        // Faint links make the continuous, non-intersecting route readable on a small screen.
        let route = CGMutablePath()
        for (index, point) in BoardDefinition.track.enumerated() {
            if index == 0 { route.move(to: location(point)) } else { route.addLine(to: location(point)) }
        }
        route.closeSubpath()
        let routeNode = SKShapeNode(path: route)
        routeNode.strokeColor = theme.woodDark.withAlphaComponent(0.2); routeNode.lineWidth = step * 0.11
        boardLayer.addChild(routeNode)
        for (index, point) in BoardDefinition.track.enumerated() {
            let color = Seat.allCases.first { $0.entry == index }?.uiColor
            hole(at: location(point), color: color)
        }
        for seat in Seat.allCases {
            for index in 0..<5 {
                hole(at: location(BoardDefinition.home(seat, index)), color: seat.uiColor)
                hole(at: location(BoardDefinition.reserve(seat, index)), color: seat.uiColor.withAlphaComponent(0.45), reserve: true)
            }
        }
        let title = SKLabelNode(text: "M")
        title.fontName = "Georgia-Bold"; title.fontSize = step * 0.56
        title.fontColor = theme.woodDark.withAlphaComponent(0.65)
        title.position = location(BoardPoint(x: 6, y: 6)); title.verticalAlignmentMode = .center
        boardLayer.addChild(title)
    }
    private func hole(at point: CGPoint, color: UIColor?, reserve: Bool = false) {
        let radius = step * (reserve ? 0.27 : 0.29)
        let shadow = SKShapeNode(circleOfRadius: radius + 1)
        shadow.position = CGPoint(x: point.x, y: point.y - 1)
        shadow.fillColor = UIColor.white.withAlphaComponent(0.32); shadow.strokeColor = .clear
        boardLayer.addChild(shadow)
        let node = SKShapeNode(circleOfRadius: radius)
        node.position = point
        node.fillColor = (color ?? UIColor(hex: 0xEEE6D6)).withAlphaComponent(reserve ? 0.42 : 0.8)
        node.strokeColor = theme.woodDark.withAlphaComponent(0.35); node.lineWidth = 1
        boardLayer.addChild(node)
        let inset = SKShapeNode(circleOfRadius: radius * 0.70)
        inset.position = CGPoint(x: 0, y: 1); inset.fillColor = .black.withAlphaComponent(0.10); inset.strokeColor = .clear
        node.addChild(inset)
    }
    private func drawMarbles(animated: Bool) {
        for marble in currentMarbles {
            let node: SKNode
            if let existing = marbleNodes[marble.id] { node = existing }
            else {
                node = SKNode(); marbleNodes[marble.id] = node; marbleLayer.addChild(node)
                node.position = location(BoardDefinition.point(for: marble))
            }
            node.removeAllChildren()
            let shadow = SKShapeNode(ellipseOf: CGSize(width: step * 0.89, height: step * 0.49))
            shadow.position = CGPoint(x: 1, y: -step * 0.32)
            shadow.fillColor = .black.withAlphaComponent(0.22); shadow.strokeColor = .clear
            node.addChild(shadow)
            let sphere = SKSpriteNode(texture: marbleTexture(marble.owner), size: CGSize(width: step * 0.9, height: step * 0.9))
            node.addChild(sphere)
            let glyph = SKLabelNode(text: marble.owner.glyph)
            glyph.fontName = "HelveticaNeue-Medium"; glyph.fontSize = step * 0.30
            glyph.verticalAlignmentMode = .center; glyph.position.y = -step * 0.02
            glyph.fontColor = .white.withAlphaComponent(0.87); node.addChild(glyph)
            let destination = location(BoardDefinition.point(for: marble))
            if node.position != destination {
                node.removeAllActions()
                if animated {
                    let action = SKAction.move(to: destination, duration: 0.33)
                    action.timingMode = .easeInEaseOut; node.run(action)
                } else { node.position = destination }
            }
        }
    }
    private func drawHighlights() {
        highlightLayer.removeAllChildren()
        for marble in currentMarbles where selectedIDs.contains(marble.id) {
            let ring = SKShapeNode(circleOfRadius: step * 0.55)
            ring.position = location(BoardDefinition.point(for: marble))
            ring.strokeColor = .white; ring.glowWidth = motionReduced ? 0 : 2; ring.lineWidth = 2.5
            ring.fillColor = .clear; highlightLayer.addChild(ring)
        }
        guard let preview else { return }
        for (index, position) in preview.path.enumerated() {
            let point: BoardPoint
            switch position {
            case .track(let index): point = BoardDefinition.track[index]
            case .home(let index): point = BoardDefinition.home(previewOwner, index)
            case .reserve: continue
            }
            let ring = SKShapeNode(circleOfRadius: step * (index == preview.path.count - 1 ? 0.46 : 0.19))
            ring.position = location(point); ring.strokeColor = .white
            ring.fillColor = previewOwner.uiColor.withAlphaComponent(0.45); ring.lineWidth = 2
            highlightLayer.addChild(ring)
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        let nearest = currentMarbles.min {
            distance(location(BoardDefinition.point(for: $0)), point) < distance(location(BoardDefinition.point(for: $1)), point)
        }
        if let nearest, distance(location(BoardDefinition.point(for: nearest)), point) < max(step * 0.6, 22) {
            onMarbleTap?(nearest.id)
        }
    }
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x-b.x, a.y-b.y) }
    private func woodTexture() -> SKTexture {
        if let texture = textures["wood"] { return texture }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024)).image { context in
            let rect = CGRect(x: 2, y: 2, width: 1020, height: 1020)
            let border = UIBezierPath(roundedRect: rect, cornerRadius: 70)
            border.addClip()
            let colors = [theme.wood, theme.woodDark.withAlphaComponent(0.75), theme.wood].map(\.cgColor) as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0,0.6,1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 1024,y: 1024), options: [])
            var random = SeededRandom(seed: 33)
            for _ in 0..<310 {
                let y = Double(random.next() % 1024)
                let bend = Double(random.next() % 100) - 50
                let path = UIBezierPath()
                path.move(to: CGPoint(x: -20, y: y))
                path.addCurve(to: CGPoint(x: 1050, y: y+bend), controlPoint1: CGPoint(x: 300,y: y-18), controlPoint2: CGPoint(x: 680,y: y+bend+20))
                theme.woodDark.withAlphaComponent(CGFloat(random.next()%10+3)/100).setStroke()
                path.lineWidth = CGFloat(random.next()%3+1); path.stroke()
            }
            theme.woodDark.withAlphaComponent(0.7).setStroke(); border.lineWidth = 7; border.stroke()
            let inner = UIBezierPath(roundedRect: rect.insetBy(dx: 12,dy: 12), cornerRadius: 61)
            UIColor.white.withAlphaComponent(0.17).setStroke(); inner.lineWidth = 2; inner.stroke()
        }
        let texture = SKTexture(image: image); textures["wood"] = texture; return texture
    }
    private func marbleTexture(_ seat: Seat) -> SKTexture {
        let key = "marble-\(seat.rawValue)"
        if let texture = textures[key] { return texture }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { renderer in
            let ctx = renderer.cgContext
            ctx.addEllipse(in: CGRect(x: 3,y: 3,width: 122,height: 122)); ctx.clip()
            let colors = [UIColor.white.withAlphaComponent(0.92), seat.uiColor, UIColor.black].map(\.cgColor) as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0,0.34,1])!
            ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: 34,y: 27), startRadius: 0,
                                   endCenter: CGPoint(x: 45,y: 40), endRadius: 117, options: .drawsAfterEndLocation)
            UIColor.white.withAlphaComponent(theme == .coastal ? 0.40 : 0.68).setFill()
            UIBezierPath(ovalIn: CGRect(x: 23,y: 15,width: 34,height: 16)).fill()
            if theme == .walnut {
                let arc = UIBezierPath(arcCenter: CGPoint(x: 64,y: 64), radius: 44, startAngle: 0.2, endAngle: 2.4, clockwise: true)
                UIColor.white.withAlphaComponent(0.22).setStroke(); arc.lineWidth = 4; arc.stroke()
            }
        }
        let texture = SKTexture(image: image); textures[key] = texture; return texture
    }
}
