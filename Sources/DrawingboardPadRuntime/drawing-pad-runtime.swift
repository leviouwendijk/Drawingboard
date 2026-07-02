import DrawingboardCore
import DrawingboardProtocol
import Foundation

public struct DrawingPadRuntime: Sendable {
    public let page: DrawingPageIdentifier
    public let tool: DrawingTool

    public init(
        page: DrawingPageIdentifier,
        tool: DrawingTool
    ) {
        self.page = page
        self.tool = tool
    }

    public func begin(
        stroke id: DrawingStrokeIdentifier = .next(),
        at point: DrawingPoint
    ) throws -> DrawingMessage {
        .event(
            .stroke_began(
                try DrawingStroke(
                    id: id,
                    page: page,
                    tool: tool,
                    points: [
                        point,
                    ]
                )
            )
        )
    }

    public func move(
        stroke id: DrawingStrokeIdentifier,
        points: [DrawingPoint]
    ) -> DrawingMessage {
        .event(
            .stroke_moved(
                DrawingStrokeMove(
                    stroke: id,
                    points: points
                )
            )
        )
    }

    public func end(
        stroke id: DrawingStrokeIdentifier,
        points: [DrawingPoint] = []
    ) -> DrawingMessage {
        .event(
            .stroke_ended(
                DrawingStrokeEnd(
                    stroke: id,
                    points: points
                )
            )
        )
    }
}
