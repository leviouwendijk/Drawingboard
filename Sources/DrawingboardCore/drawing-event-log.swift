import Foundation

public enum DrawingEventLogError: Error, Sendable, LocalizedError, Equatable {
    case invalidSequence(expected: UInt64, actual: UInt64)
    case sequenceOverflow

    public var errorDescription: String? {
        switch self {
        case .invalidSequence(let expected, let actual):
            "Invalid event sequence. Expected \(expected), received \(actual)."

        case .sequenceOverflow:
            "Drawing event sequence overflow."
        }
    }
}

public struct DrawingEventRecord: Sendable, Codable, Hashable {
    public let sequence: UInt64
    public let time: TimeInterval
    public let event: DrawingEvent

    public init(
        sequence: UInt64,
        time: TimeInterval,
        event: DrawingEvent
    ) {
        self.sequence = sequence
        self.time = time
        self.event = event
    }
}

public struct DrawingEventLog: Sendable, Hashable {
    public private(set) var records: [DrawingEventRecord]

    public init() {
        self.records = []
    }

    public init(
        records: [DrawingEventRecord]
    ) throws {
        try Self.validate(
            records: records
        )

        self.records = records
    }

    @discardableResult
    public mutating func append(
        _ event: DrawingEvent,
        time: TimeInterval
    ) throws -> DrawingEventRecord {
        let sequence: UInt64

        if let last = records.last {
            guard last.sequence < UInt64.max else {
                throw DrawingEventLogError.sequenceOverflow
            }

            sequence = last.sequence + 1
        } else {
            sequence = 0
        }

        let record = DrawingEventRecord(
            sequence: sequence,
            time: time,
            event: event
        )

        records.append(
            record
        )

        return record
    }

    private static func validate(
        records: [DrawingEventRecord]
    ) throws {
        for (index, record) in records.enumerated() {
            let expected = UInt64(
                index
            )

            guard record.sequence == expected else {
                throw DrawingEventLogError.invalidSequence(
                    expected: expected,
                    actual: record.sequence
                )
            }
        }
    }
}

public struct DrawingDocumentReplayer: Sendable {
    private let reducer: DrawingDocumentReducer

    public init(
        reducer: DrawingDocumentReducer = DrawingDocumentReducer()
    ) {
        self.reducer = reducer
    }

    public func replay(
        records: [DrawingEventRecord],
        from document: DrawingDocument
    ) throws -> DrawingDocumentState {
        var state = DrawingDocumentState(
            document: document
        )

        for record in records {
            try reducer.apply(
                record.event,
                to: &state
            )
        }

        return state
    }

    public func replay(
        log: DrawingEventLog,
        from document: DrawingDocument
    ) throws -> DrawingDocumentState {
        try replay(
            records: log.records,
            from: document
        )
    }
}
