import DrawingboardCore
import Foundation

public enum DrawingEventRecordCodecError: Error, Sendable, LocalizedError, Equatable {
    case invalidUTF8

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            "Drawing event log contains invalid UTF-8."
        }
    }
}

public struct DrawingEventRecordCodec: Sendable {
    public init() {}

    public func encode(
        _ record: DrawingEventRecord
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys,
        ]

        return try encoder.encode(
            record
        )
    }

    public func decode(
        _ data: Data
    ) throws -> DrawingEventRecord {
        let decoder = JSONDecoder()

        return try decoder.decode(
            DrawingEventRecord.self,
            from: data
        )
    }

    public func encodeLine(
        _ record: DrawingEventRecord
    ) throws -> Data {
        var data = try encode(
            record
        )
        data.append(
            0x0A
        )

        return data
    }

    public func encodeLog(
        _ log: DrawingEventLog
    ) throws -> Data {
        var data = Data()

        for record in log.records {
            data.append(
                try encodeLine(
                    record
                )
            )
        }

        return data
    }

    public func decodeLog(
        _ data: Data
    ) throws -> DrawingEventLog {
        guard let text = String(
            data: data,
            encoding: .utf8
        ) else {
            throw DrawingEventRecordCodecError.invalidUTF8
        }

        var records: [DrawingEventRecord] = []

        for line in text.split(
            separator: "\n",
            omittingEmptySubsequences: true
        ) {
            records.append(
                try decode(
                    Data(
                        line.utf8
                    )
                )
            )
        }

        return try DrawingEventLog(
            records: records
        )
    }
}
