import DrawingboardCore
import DrawingboardProtocol
import Foundation

public enum DrawingPadStrokeBatcherError: Error, Sendable, LocalizedError, Equatable {
    case strokeAlreadyOpen(String)
    case missingOpenStroke

    public var errorDescription: String? {
        switch self {
        case .strokeAlreadyOpen(let id):
            "A stroke is already open: \(id)."

        case .missingOpenStroke:
            "No stroke is currently open."
        }
    }
}

public struct DrawingPadStrokeBatcher: Sendable {
    public private(set) var page: DrawingPageIdentifier
    public private(set) var tool: DrawingTool
    public let maximumPointCount: Int

    public private(set) var openStroke: DrawingStrokeIdentifier?
    private var pendingPoints: [DrawingPoint]

    public init(
        page: DrawingPageIdentifier,
        tool: DrawingTool,
        maximumPointCount: Int = 8
    ) throws {
        guard maximumPointCount > 0 else {
            throw DrawingError.invalidStrokeWidth(
                Double(maximumPointCount)
            )
        }

        self.page = page
        self.tool = tool
        self.maximumPointCount = maximumPointCount
        self.openStroke = nil
        self.pendingPoints = []
    }

    public mutating func setPage(
        _ page: DrawingPageIdentifier
    ) throws {
        guard openStroke == nil else {
            throw DrawingPadStrokeBatcherError.strokeAlreadyOpen(
                openStroke?.rawValue ?? ""
            )
        }

        self.page = page
    }

    public mutating func setTool(
        _ tool: DrawingTool
    ) throws {
        guard openStroke == nil else {
            throw DrawingPadStrokeBatcherError.strokeAlreadyOpen(
                openStroke?.rawValue ?? ""
            )
        }

        self.tool = tool
    }

    public mutating func begin(
        stroke id: DrawingStrokeIdentifier = .next(),
        at point: DrawingPoint
    ) throws -> DrawingMessage {
        guard openStroke == nil else {
            throw DrawingPadStrokeBatcherError.strokeAlreadyOpen(
                openStroke?.rawValue ?? ""
            )
        }

        openStroke = id
        pendingPoints = []

        let stroke = try DrawingStroke(
            id: id,
            page: page,
            tool: tool,
            points: [
                point,
            ]
        )

        return .event(
            .stroke_began(
                stroke
            )
        )
    }

    public mutating func append(
        points: [DrawingPoint]
    ) throws -> [DrawingMessage] {
        guard let stroke = openStroke else {
            throw DrawingPadStrokeBatcherError.missingOpenStroke
        }

        guard !points.isEmpty else {
            return []
        }

        pendingPoints.append(
            contentsOf: points
        )

        return flushFullBatches(
            stroke: stroke
        )
    }

    public mutating func flush() throws -> [DrawingMessage] {
        guard let stroke = openStroke else {
            throw DrawingPadStrokeBatcherError.missingOpenStroke
        }

        guard !pendingPoints.isEmpty else {
            return []
        }

        let points = pendingPoints
        pendingPoints.removeAll()

        return [
            .event(
                .stroke_moved(
                    DrawingStrokeMove(
                        stroke: stroke,
                        points: points
                    )
                )
            ),
        ]
    }

    public mutating func end(
        points: [DrawingPoint] = []
    ) throws -> [DrawingMessage] {
        guard let stroke = openStroke else {
            throw DrawingPadStrokeBatcherError.missingOpenStroke
        }

        if !points.isEmpty {
            pendingPoints.append(
                contentsOf: points
            )
        }

        var messages = flushFullBatches(
            stroke: stroke
        )

        let remainingPoints = pendingPoints
        pendingPoints.removeAll()
        openStroke = nil

        messages.append(
            .event(
                .stroke_ended(
                    DrawingStrokeEnd(
                        stroke: stroke,
                        points: remainingPoints
                    )
                )
            )
        )

        return messages
    }

    public mutating func cancel() throws -> DrawingMessage {
        guard let stroke = openStroke else {
            throw DrawingPadStrokeBatcherError.missingOpenStroke
        }

        pendingPoints.removeAll()
        openStroke = nil

        return .event(
            .stroke_cancelled(
                stroke
            )
        )
    }
}

private extension DrawingPadStrokeBatcher {
    mutating func flushFullBatches(
        stroke: DrawingStrokeIdentifier
    ) -> [DrawingMessage] {
        var messages: [DrawingMessage] = []

        while pendingPoints.count >= maximumPointCount {
            let batch = Array(
                pendingPoints.prefix(
                    maximumPointCount
                )
            )

            pendingPoints.removeFirst(
                maximumPointCount
            )

            messages.append(
                .event(
                    .stroke_moved(
                        DrawingStrokeMove(
                            stroke: stroke,
                            points: batch
                        )
                    )
                )
            )
        }

        return messages
    }
}
