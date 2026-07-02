import DrawingboardCore
import Foundation

public enum DrawingRenderError: Error, Sendable, LocalizedError, Equatable {
    case missingActivePage(String)
    case emptyRenderedStroke(String)
    case invalidRenderedStrokeWidth(Double)

    public var errorDescription: String? {
        switch self {
        case .missingActivePage(let page):
            "Missing active page for rendering: \(page)."

        case .emptyRenderedStroke(let stroke):
            "Cannot render empty stroke: \(stroke)."

        case .invalidRenderedStrokeWidth(let width):
            "Invalid rendered stroke width: \(width)."
        }
    }
}

public struct DrawingRenderStrokeCommand: Sendable, Codable, Hashable {
    public let id: DrawingStrokeIdentifier
    public let page: DrawingPageIdentifier
    public let points: [DrawingCoordinate]
    public let color: DrawingRGBA
    public let width: Double
    public let isOpen: Bool
    public let bounds: DrawingBounds

    public init(
        id: DrawingStrokeIdentifier,
        page: DrawingPageIdentifier,
        points: [DrawingCoordinate],
        color: DrawingRGBA,
        width: Double,
        isOpen: Bool,
        bounds: DrawingBounds
    ) throws {
        guard !points.isEmpty else {
            throw DrawingRenderError.emptyRenderedStroke(
                id.rawValue
            )
        }

        guard width > 0,
              width.isFinite else {
            throw DrawingRenderError.invalidRenderedStrokeWidth(
                width
            )
        }

        self.id = id
        self.page = page
        self.points = points
        self.color = color
        self.width = width
        self.isOpen = isOpen
        self.bounds = bounds
    }
}

public enum DrawingRenderCommand: Sendable, Codable, Hashable {
    case stroke(DrawingRenderStrokeCommand)
}

public struct DrawingRenderFrame: Sendable, Codable, Hashable {
    public let page: DrawingPageIdentifier
    public let viewport: DrawingViewport
    public let commands: [DrawingRenderCommand]

    public init(
        page: DrawingPageIdentifier,
        viewport: DrawingViewport,
        commands: [DrawingRenderCommand]
    ) {
        self.page = page
        self.viewport = viewport
        self.commands = commands
    }
}
