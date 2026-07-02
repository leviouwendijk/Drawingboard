import DrawingboardCore
import Foundation

public struct DrawingBounds: Sendable, Codable, Hashable {
    public let minX: Double
    public let minY: Double
    public let maxX: Double
    public let maxY: Double

    public init(
        minX: Double,
        minY: Double,
        maxX: Double,
        maxY: Double
    ) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public var width: Double {
        maxX - minX
    }

    public var height: Double {
        maxY - minY
    }
}

public struct DrawingStrokeBounds: Sendable {
    public init() {}

    public func resolve(
        stroke: DrawingStroke
    ) -> DrawingBounds? {
        guard let first = stroke.points.first else {
            return nil
        }

        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y

        for point in stroke.points.dropFirst() {
            minX = min(
                minX,
                point.x
            )
            minY = min(
                minY,
                point.y
            )
            maxX = max(
                maxX,
                point.x
            )
            maxY = max(
                maxY,
                point.y
            )
        }

        let margin = stroke.tool.width / 2

        return DrawingBounds(
            minX: minX - margin,
            minY: minY - margin,
            maxX: maxX + margin,
            maxY: maxY + margin
        )
    }
}
