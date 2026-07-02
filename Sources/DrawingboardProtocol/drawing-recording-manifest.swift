import DrawingboardCore
import Foundation

public struct DrawingRecordingManifest: Sendable, Codable, Hashable {
    public let document: DrawingDocumentIdentifier
    public let activePage: DrawingPageIdentifier
    public let pageSize: DrawingSize
    public let eventLogFile: String

    public init(
        document: DrawingDocumentIdentifier,
        activePage: DrawingPageIdentifier,
        pageSize: DrawingSize,
        eventLogFile: String = "drawingboard-events.jsonl"
    ) {
        self.document = document
        self.activePage = activePage
        self.pageSize = pageSize
        self.eventLogFile = eventLogFile
    }
}

public struct DrawingRecordingManifestStore: Sendable {
    public init() {}

    public func write(
        _ manifest: DrawingRecordingManifest,
        to url: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
        ]

        let data = try encoder.encode(
            manifest
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
    ) throws -> DrawingRecordingManifest {
        let data = try Data(
            contentsOf: url
        )

        return try JSONDecoder().decode(
            DrawingRecordingManifest.self,
            from: data
        )
    }
}
