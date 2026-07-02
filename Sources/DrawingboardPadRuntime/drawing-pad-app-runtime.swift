import DrawingboardCore
import DrawingboardProtocol
import Foundation

public typealias DrawingPadMessageSink = @Sendable (DrawingMessage) async throws -> Void

public actor DrawingPadAppRuntime {
    private var batcher: DrawingPadStrokeBatcher
    private let sink: DrawingPadMessageSink

    public init(
        page: DrawingPageIdentifier,
        tool: DrawingTool,
        maximumPointCount: Int = 8,
        sink: @escaping DrawingPadMessageSink
    ) throws {
        self.batcher = try DrawingPadStrokeBatcher(
            page: page,
            tool: tool,
            maximumPointCount: maximumPointCount
        )
        self.sink = sink
    }

    public func openStroke() -> DrawingStrokeIdentifier? {
        batcher.openStroke
    }

    public func tool() -> DrawingTool {
        batcher.tool
    }

    public func setTool(
        _ tool: DrawingTool
    ) throws {
        try batcher.setTool(
            tool
        )
    }

    public func begin(
        stroke id: DrawingStrokeIdentifier = .next(),
        at point: DrawingPoint
    ) async throws {
        try await send(
            [
                try batcher.begin(
                    stroke: id,
                    at: point
                ),
            ]
        )
    }

    public func append(
        points: [DrawingPoint]
    ) async throws {
        try await send(
            try batcher.append(
                points: points
            )
        )
    }

    public func flush() async throws {
        try await send(
            try batcher.flush()
        )
    }

    public func end(
        points: [DrawingPoint] = []
    ) async throws {
        try await send(
            try batcher.end(
                points: points
            )
        )
    }

    public func cancel() async throws {
        try await send(
            [
                try batcher.cancel(),
            ]
        )
    }

    public func remove(
        stroke id: DrawingStrokeIdentifier
    ) async throws {
        try await send(
            [
                .event(
                    .stroke_removed(
                        id
                    )
                ),
            ]
        )
    }
}

private extension DrawingPadAppRuntime {
    func send(
        _ messages: [DrawingMessage]
    ) async throws {
        for message in messages {
            try await sink(
                message
            )
        }
    }
}
