import Foundation

public struct DrawingStrokeMove: Sendable, Codable, Hashable {
    public let stroke: DrawingStrokeIdentifier
    public let points: [DrawingPoint]

    public init(
        stroke: DrawingStrokeIdentifier,
        points: [DrawingPoint]
    ) {
        self.stroke = stroke
        self.points = points
    }
}

public struct DrawingStrokeEnd: Sendable, Codable, Hashable {
    public let stroke: DrawingStrokeIdentifier
    public let points: [DrawingPoint]

    public init(
        stroke: DrawingStrokeIdentifier,
        points: [DrawingPoint] = []
    ) {
        self.stroke = stroke
        self.points = points
    }
}

public enum DrawingEvent: Sendable, Codable, Hashable {
    case page_created(DrawingPage)
    case page_selected(DrawingPageIdentifier)
    case page_cleared(DrawingPageIdentifier)
    case page_restored(DrawingPage)
    case page_deleted(DrawingPageIdentifier)
    case stroke_began(DrawingStroke)
    case stroke_moved(DrawingStrokeMove)
    case stroke_ended(DrawingStrokeEnd)
    case stroke_cancelled(DrawingStrokeIdentifier)
    case stroke_removed(DrawingStrokeIdentifier)
    case stroke_restored(DrawingStroke)
}
