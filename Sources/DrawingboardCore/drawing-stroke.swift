import Foundation

public struct DrawingStroke: Sendable, Codable, Hashable, Identifiable {
    public let id: DrawingStrokeIdentifier
    public let page: DrawingPageIdentifier
    public let tool: DrawingTool
    public var points: [DrawingPoint]

    public init(
        id: DrawingStrokeIdentifier = .next(),
        page: DrawingPageIdentifier,
        tool: DrawingTool,
        points: [DrawingPoint]
    ) throws {
        guard !points.isEmpty else {
            throw DrawingError.emptyStroke
        }

        self.id = id
        self.page = page
        self.tool = tool
        self.points = points
    }

    public mutating func append(
        points newPoints: [DrawingPoint]
    ) throws {
        guard !newPoints.isEmpty else {
            throw DrawingError.emptyStroke
        }

        points.append(
            contentsOf: newPoints
        )
    }
}
