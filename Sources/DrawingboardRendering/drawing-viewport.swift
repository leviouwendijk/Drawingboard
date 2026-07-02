import DrawingboardCore
import Foundation

public struct DrawingViewport: Sendable, Codable, Hashable {
    public let pageSize: DrawingSize
    public let viewSize: DrawingSize
    public let scale: Double
    public let offset: DrawingVector

    public init(
        pageSize: DrawingSize,
        viewSize: DrawingSize,
        scale: Double = 1,
        offset: DrawingVector = DrawingVector(
            dx: 0,
            dy: 0
        )
    ) throws {
        guard scale > 0,
              scale.isFinite else {
            throw DrawingViewportError.invalidScale(
                scale
            )
        }

        self.pageSize = pageSize
        self.viewSize = viewSize
        self.scale = scale
        self.offset = offset
    }

    public func pageToView(
        _ coordinate: DrawingCoordinate
    ) -> DrawingCoordinate {
        DrawingCoordinate(
            x: coordinate.x * scale + offset.dx,
            y: coordinate.y * scale + offset.dy
        )
    }

    public func viewToPage(
        _ coordinate: DrawingCoordinate
    ) -> DrawingCoordinate {
        DrawingCoordinate(
            x: (coordinate.x - offset.dx) / scale,
            y: (coordinate.y - offset.dy) / scale
        )
    }

    public func panned(
        by delta: DrawingVector
    ) throws -> DrawingViewport {
        try DrawingViewport(
            pageSize: pageSize,
            viewSize: viewSize,
            scale: scale,
            offset: DrawingVector(
                dx: offset.dx + delta.dx,
                dy: offset.dy + delta.dy
            )
        )
    }

    public func zoomed(
        by factor: Double,
        around anchor: DrawingCoordinate
    ) throws -> DrawingViewport {
        guard factor > 0,
              factor.isFinite else {
            throw DrawingViewportError.invalidZoomFactor(
                factor
            )
        }

        let pageAnchor = viewToPage(
            anchor
        )
        let newScale = scale * factor

        guard newScale > 0,
              newScale.isFinite else {
            throw DrawingViewportError.invalidScale(
                newScale
            )
        }

        return try DrawingViewport(
            pageSize: pageSize,
            viewSize: viewSize,
            scale: newScale,
            offset: DrawingVector(
                dx: anchor.x - pageAnchor.x * newScale,
                dy: anchor.y - pageAnchor.y * newScale
            )
        )
    }

    public static func fitPage(
        pageSize: DrawingSize,
        viewSize: DrawingSize,
        margin: Double = 0
    ) throws -> DrawingViewport {
        guard margin >= 0,
              margin.isFinite else {
            throw DrawingViewportError.invalidMargin(
                margin
            )
        }

        let availableWidth = viewSize.width - margin * 2
        let availableHeight = viewSize.height - margin * 2

        guard availableWidth > 0,
              availableHeight > 0 else {
            throw DrawingViewportError.viewportTooSmall(
                width: viewSize.width,
                height: viewSize.height,
                margin: margin
            )
        }

        let scale = min(
            availableWidth / pageSize.width,
            availableHeight / pageSize.height
        )

        let renderedWidth = pageSize.width * scale
        let renderedHeight = pageSize.height * scale

        return try DrawingViewport(
            pageSize: pageSize,
            viewSize: viewSize,
            scale: scale,
            offset: DrawingVector(
                dx: (viewSize.width - renderedWidth) / 2,
                dy: (viewSize.height - renderedHeight) / 2
            )
        )
    }
}
