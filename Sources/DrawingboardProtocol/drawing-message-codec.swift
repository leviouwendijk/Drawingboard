import Foundation

public struct DrawingMessageCodec: Sendable {
    public init() {}

    public func encode(
        _ message: DrawingMessage
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .sortedKeys,
        ]

        return try encoder.encode(
            message
        )
    }

    public func decode(
        _ data: Data
    ) throws -> DrawingMessage {
        let decoder = JSONDecoder()

        return try decoder.decode(
            DrawingMessage.self,
            from: data
        )
    }
}
