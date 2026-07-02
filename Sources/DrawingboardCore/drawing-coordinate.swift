import Foundation

public struct DrawingCoordinate: Sendable, Codable, Hashable {
    public let x: Double
    public let y: Double

    public init(
        x: Double,
        y: Double
    ) {
        self.x = x
        self.y = y
    }
}

public struct DrawingVector: Sendable, Codable, Hashable {
    public let dx: Double
    public let dy: Double

    public init(
        dx: Double,
        dy: Double
    ) {
        self.dx = dx
        self.dy = dy
    }
}
