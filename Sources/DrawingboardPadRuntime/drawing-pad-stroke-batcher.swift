import DrawingboardCore
import DrawingboardProtocol
import Foundation

public enum DrawingPadStrokeBatcherError: Error, Sendable, LocalizedError, Equatable {
    case invalidMaximumPointCount(Int)
    case strokeAlreadyOpen(String)
    case missingOpenStroke
    case mismatchedStroke(expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case .invalidMaximumPointCount(let count):
            "Invalid maximum point count: \(count)."

        case .strokeAlreadyOpen(let stroke):
            "Stroke is already open: \(stroke)."

        case .missingOpenStroke:
            "Cannot batch points without an open stroke."

        case .mismatchedStroke(let expected, let actual):
            "Mismatched stroke. Expected \(expected), received \(actual)."
        }
    }
}

public struct DrawingPadStrokeBatcher: Sendable {
    public let page: DrawingPageIdentifier
    public let tool: DrawingTool
    public let maximumPointCount: Int

    public private(set) var openStroke: DrawingStrokeIdentifier?
    private var pendingPoints: [DrawingPoint]

    public init(
        page: DrawingPageIdentifier,
        tool: DrawingTool,
        maximumPointCount: Int = 16
    ) throws {
        guard maximumPointCount > 0 else {
            throw DrawingPadStrokeBatcherError.invalidMaximumPointCount(
                maximumPointCount
            )
        }

        self.page = page
        self.tool = tool
        self.maximumPointCount = maximumPointCount
        self.openStroke = nil
        self.pendingPoints = []
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
        pendingPoints.removeAll()

        return .event(
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

        return makeMoveMessages(
            stroke: stroke,
            flushingFullBatchesOnly: true
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
        stroke explicitStroke: DrawingStrokeIdentifier? = nil,
        points: [DrawingPoint] = []
    ) throws -> [DrawingMessage] {
        guard let stroke = openStroke else {
            throw DrawingPadStrokeBatcherError.missingOpenStroke
        }

        if let explicitStroke,
           explicitStroke != stroke {
            throw DrawingPadStrokeBatcherError.mismatchedStroke(
                expected: stroke.rawValue,
                actual: explicitStroke.rawValue
            )
        }

        pendingPoints.append(
            contentsOf: points
        )

        var messages = makeMoveMessages(
            stroke: stroke,
            flushingFullBatchesOnly: false
        )

        messages.append(
            .event(
                .stroke_ended(
                    DrawingStrokeEnd(
                        stroke: stroke,
                        points: pendingPoints
                    )
                )
            )
        )

        pendingPoints.removeAll()
        openStroke = nil

        return messages
    }

    public mutating func cancel(
        stroke explicitStroke: DrawingStrokeIdentifier? = nil
    ) throws -> DrawingMessage {
        guard let stroke = openStroke else {
            throw DrawingPadStrokeBatcherError.missingOpenStroke
        }

        if let explicitStroke,
           explicitStroke != stroke {
            throw DrawingPadStrokeBatcherError.mismatchedStroke(
                expected: stroke.rawValue,
                actual: explicitStroke.rawValue
            )
        }

        pendingPoints.removeAll()
        openStroke = nil

        return .event(
            .stroke_cancelled(
                stroke
            )
        )
    }

    private mutating func makeMoveMessages(
        stroke: DrawingStrokeIdentifier,
        flushingFullBatchesOnly: Bool
    ) -> [DrawingMessage] {
        var messages: [DrawingMessage] = []

        while pendingPoints.count > maximumPointCount ||
              flushingFullBatchesOnly && pendingPoints.count >= maximumPointCount {
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
