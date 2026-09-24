import Foundation

public struct BoardPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public enum BoardDefinition {
    /// Photograph coordinates, top left origin. The 48 unique spaces form a single loop.
    public static let track: [BoardPoint] = {
        let corners = [(0,5),(5,5),(5,0),(7,0),(7,5),(12,5),(12,7),(7,7),(7,12),(5,12),(5,7),(0,7),(0,5)]
        var points: [BoardPoint] = []
        for index in 0..<(corners.count - 1) {
            var (x,y) = corners[index]
            let (tx,ty) = corners[index + 1]
            while x != tx || y != ty {
                points.append(BoardPoint(x: Double(x), y: Double(y)))
                x += (tx - x).signum(); y += (ty - y).signum()
            }
        }
        return points
    }()
    public static func home(_ seat: Seat, _ index: Int) -> BoardPoint {
        switch seat {
        case .red: BoardPoint(x: Double(index + 1), y: 6)
        case .yellow: BoardPoint(x: 6, y: Double(index + 1))
        case .green: BoardPoint(x: Double(11 - index), y: 6)
        case .blue: BoardPoint(x: 6, y: Double(11 - index))
        }
    }
    public static func reserve(_ seat: Seat, _ index: Int) -> BoardPoint {
        let points = [(1.1,1.3),(3.3,1.3),(2.2,2.7),(1.1,4.0),(3.3,4.0)]
        let (x,y) = points[index % 5]
        switch seat {
        case .red: return BoardPoint(x: x, y: y)
        case .yellow: return BoardPoint(x: 12-x, y: y)
        case .green: return BoardPoint(x: 12-x, y: 12-y)
        case .blue: return BoardPoint(x: x, y: 12-y)
        }
    }
    public static func point(for marble: Marble) -> BoardPoint {
        switch marble.position {
        case .reserve: reserve(marble.owner, marble.id % 5)
        case .track(let index): track[index]
        case .home(let index): home(marble.owner, index)
        }
    }
}
