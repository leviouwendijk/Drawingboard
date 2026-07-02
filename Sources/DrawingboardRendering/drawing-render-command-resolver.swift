import DrawingboardCore
import Foundation

public struct DrawingRenderCommandResolver: Sendable {
    public init() {}

    public func resolve(
        state: DrawingDocumentState,
        viewport: DrawingViewport
    ) throws -> DrawingRenderFrame {
        guard let page = state.document.pages.first(where: { $0.id == state.document.activePage }) else {
            throw DrawingRenderError.missingActivePage(
                state.document.activePage.rawValue
            )
        }

        var commands: [DrawingRenderCommand] = []

        for stroke in page.strokes {
            commands.append(
                .stroke(
                    try render(
                        stroke: stroke,
                        viewport: viewport,
                        isOpen: false
                    )
                )
            )
        }

        let openStrokes = state.openStrokes.values
            .filter { $0.page == page.id }
            .sorted { left, right in
                left.id.rawValue < right.id.rawValue
            }

        for stroke in openStrokes {
            commands.append(
                .stroke(
                    try render(
                        stroke: stroke,
                        viewport: viewport,
                        isOpen: true
                    )
                )
            )
        }

        return DrawingRenderFrame(
            page: page.id,
            viewport: viewport,
            commands: commands
        )
    }
}

private extension DrawingRenderCommandResolver {
    func render(
        stroke: DrawingStroke,
        viewport: DrawingViewport,
        isOpen: Bool
    ) throws -> DrawingRenderStrokeCommand {
        let points = stroke.points.map { point in
            viewport.pageToView(
                DrawingCoordinate(
                    x: point.x,
                    y: point.y
                )
            )
        }

        guard let bounds = bounds(
            points: points,
            width: stroke.tool.width * viewport.scale
        ) else {
            throw DrawingRenderError.emptyRenderedStroke(
                stroke.id.rawValue
            )
        }

        return try DrawingRenderStrokeCommand(
            id: stroke.id,
            page: stroke.page,
            points: points,
            color: stroke.tool.color,
            width: stroke.tool.width * viewport.scale,
            isOpen: isOpen,
            bounds: bounds
        )
    }

    func bounds(
        points: [DrawingCoordinate],
        width: Double
    ) -> DrawingBounds? {
        guard let first = points.first else {
            return nil
        }

        let margin = width / 2

        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y

        for point in points.dropFirst() {
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

        return DrawingBounds(
            minX: minX - margin,
            minY: minY - margin,
            maxX: maxX + margin,
            maxY: maxY + margin
        )
    }
}
