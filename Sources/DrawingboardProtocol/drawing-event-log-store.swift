import DrawingboardCore
import Foundation

public struct DrawingEventLogStore: Sendable {
    public let codec: DrawingEventRecordCodec

    public init(
        codec: DrawingEventRecordCodec = DrawingEventRecordCodec()
    ) {
        self.codec = codec
    }

    public func reset(
        at url: URL
    ) throws {
        try Data().write(
            to: url,
            options: [
                .atomic,
            ]
        )
    }

    public func append(
        _ record: DrawingEventRecord,
        to url: URL
    ) throws {
        let data = try codec.encodeLine(
            record
        )

        if !FileManager.default.fileExists(
            atPath: url.path
        ) {
            try reset(
                at: url
            )
        }

        let handle = try FileHandle(
            forWritingTo: url
        )

        defer {
            try? handle.close()
        }

        try handle.seekToEnd()
        try handle.write(
            contentsOf: data
        )
    }

    public func write(
        _ log: DrawingEventLog,
        to url: URL
    ) throws {
        let data = try codec.encodeLog(
            log
        )

        try data.write(
            to: url,
            options: [
                .atomic,
            ]
        )
    }

    public func read(
        from url: URL
    ) throws -> DrawingEventLog {
        let data = try Data(
            contentsOf: url
        )

        return try codec.decodeLog(
            data
        )
    }
}
