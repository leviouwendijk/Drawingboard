import DrawingboardProtocol
import Foundation

public protocol DrawingMessageSending: Sendable {
    func send(
        _ message: DrawingMessage
    ) async throws
}

public protocol DrawingMessageReceiving: Sendable {
    func messages() -> AsyncThrowingStream<DrawingMessage, Error>
}

public typealias DrawingMessageTransport = DrawingMessageSending & DrawingMessageReceiving
