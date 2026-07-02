import DrawingboardProtocol
import Foundation
@preconcurrency import Network

public enum DrawingNetworkTransportError: Error, Sendable, LocalizedError, Equatable {
    case invalidPort(UInt16)
    case missingMessage
    case notConnected
    case connectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPort(let port):
            "Invalid network port: \(port)."

        case .missingMessage:
            "Expected a drawing network message, but none was received."

        case .notConnected:
            "Drawing network client is not connected."

        case .connectionFailed(let message):
            "Drawing network connection failed: \(message)"
        }
    }
}

public struct DrawingNetworkMessageLineCodec: Sendable {
    public let codec: DrawingMessageCodec

    public init(
        codec: DrawingMessageCodec = DrawingMessageCodec()
    ) {
        self.codec = codec
    }

    public func encodeLine(
        _ message: DrawingMessage
    ) throws -> Data {
        var data = try codec.encode(
            message
        )

        data.append(
            0x0A
        )

        return data
    }

    public func decodeLine(
        _ data: Data
    ) throws -> DrawingMessage {
        var line = data

        while line.last == 0x0A ||
              line.last == 0x0D {
            line.removeLast()
        }

        return try codec.decode(
            line
        )
    }
}

private final class DrawingNetworkReadyContinuation: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, any Error>?

    init(
        _ continuation: CheckedContinuation<Void, any Error>
    ) {
        self.continuation = continuation
    }

    func resume() {
        let continuation = takeContinuation()

        continuation?.resume(
            returning: ()
        )
    }

    func resume(
        throwing error: any Error
    ) {
        let continuation = takeContinuation()

        continuation?.resume(
            throwing: error
        )
    }

    private func takeContinuation() -> CheckedContinuation<Void, any Error>? {
        lock.lock()
        defer {
            lock.unlock()
        }

        let continuation = self.continuation
        self.continuation = nil

        return continuation
    }
}

public final class DrawingNetworkMessageConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let codec: DrawingNetworkMessageLineCodec

    public init(
        connection: NWConnection,
        queue: DispatchQueue = DispatchQueue(
            label: "drawingboard.network.connection"
        ),
        codec: DrawingNetworkMessageLineCodec = DrawingNetworkMessageLineCodec()
    ) {
        self.connection = connection
        self.queue = queue
        self.codec = codec
    }

    public convenience init(
        host: String,
        port: UInt16,
        queue: DispatchQueue = DispatchQueue(
            label: "drawingboard.network.client"
        ),
        codec: DrawingNetworkMessageLineCodec = DrawingNetworkMessageLineCodec()
    ) throws {
        guard let networkPort = NWEndpoint.Port(
            rawValue: port
        ) else {
            throw DrawingNetworkTransportError.invalidPort(
                port
            )
        }

        self.init(
            connection: NWConnection(
                host: NWEndpoint.Host(
                    host
                ),
                port: networkPort,
                using: .tcp
            ),
            queue: queue,
            codec: codec
        )
    }

    public func start() {
        connection.start(
            queue: queue
        )
    }

    public func send(
        _ message: DrawingMessage
    ) async throws {
        let data = try codec.encodeLine(
            message
        )

        try await withCheckedThrowingContinuation { (
            continuation: CheckedContinuation<Void, any Error>
        ) in
            connection.send(
                content: data,
                contentContext: .defaultMessage,
                isComplete: false,
                completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(
                            throwing: error
                        )
                    } else {
                        continuation.resume(
                            returning: ()
                        )
                    }
                }
            )
        }
    }

    public func messages(
        maximumLength: Int = 65_536
    ) -> AsyncThrowingStream<DrawingMessage, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var buffer = Data()

                do {
                    while !Task.isCancelled {
                        let chunk = try await receiveChunk(
                            maximumLength: maximumLength
                        )

                        if let data = chunk.data,
                           !data.isEmpty {
                            buffer.append(
                                data
                            )

                            while let newlineIndex = buffer.firstIndex(
                                of: 0x0A
                            ) {
                                let line = Data(
                                    buffer[..<newlineIndex]
                                )

                                buffer.removeSubrange(
                                    buffer.startIndex...newlineIndex
                                )

                                if !line.isEmpty {
                                    continuation.yield(
                                        try codec.decodeLine(
                                            line
                                        )
                                    )
                                }
                            }
                        }

                        if chunk.isComplete {
                            continuation.finish()
                            return
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: error
                    )
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func close() {
        connection.cancel()
    }

    public func startAndWaitUntilReady() async throws {
        try await withCheckedThrowingContinuation { (
            continuation: CheckedContinuation<Void, any Error>
        ) in
            let readiness = DrawingNetworkReadyContinuation(
                continuation
            )

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    readiness.resume()

                case .failed(let error):
                    readiness.resume(
                        throwing: error
                    )

                case .cancelled:
                    readiness.resume(
                        throwing: DrawingNetworkTransportError.connectionFailed(
                            "Connection was cancelled before becoming ready."
                        )
                    )

                default:
                    break
                }
            }

            connection.start(
                queue: queue
            )
        }
    }
}

private extension DrawingNetworkMessageConnection {
    func receiveChunk(
        maximumLength: Int
    ) async throws -> (
        data: Data?,
        isComplete: Bool
    ) {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(
                minimumIncompleteLength: 1,
                maximumLength: maximumLength
            ) { data, _, isComplete, error in
                if let error {
                    continuation.resume(
                        throwing: error
                    )
                } else {
                    continuation.resume(
                        returning: (
                            data,
                            isComplete
                        )
                    )
                }
            }
        }
    }
}

public final class DrawingNetworkHostServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue: DispatchQueue

    public init(
        port: UInt16,
        queue: DispatchQueue = DispatchQueue(
            label: "drawingboard.network.listener"
        )
    ) throws {
        guard let networkPort = NWEndpoint.Port(
            rawValue: port
        ) else {
            throw DrawingNetworkTransportError.invalidPort(
                port
            )
        }

        self.listener = try NWListener(
            using: .tcp,
            on: networkPort
        )
        self.queue = queue
    }

    public func start() -> AsyncThrowingStream<DrawingNetworkMessageConnection, Error> {
        AsyncThrowingStream { continuation in
            listener.newConnectionHandler = { connection in
                let messageConnection = DrawingNetworkMessageConnection(
                    connection: connection
                )

                messageConnection.start()

                continuation.yield(
                    messageConnection
                )
            }

            listener.stateUpdateHandler = { state in
                switch state {
                case .failed(let error):
                    continuation.finish(
                        throwing: error
                    )

                case .cancelled:
                    continuation.finish()

                default:
                    break
                }
            }

            listener.start(
                queue: queue
            )

            continuation.onTermination = { @Sendable [self] _ in
                cancel()
            }
        }
    }

    public func cancel() {
        listener.cancel()
    }
}

public final class DrawingNetworkPadClient: @unchecked Sendable {
    private let host: String
    private let port: UInt16
    private let lock = NSLock()

    private var connection: DrawingNetworkMessageConnection?

    public init(
        host: String,
        port: UInt16
    ) throws {
        self.host = host
        self.port = port
    }

    public func start() {
        // Intentionally empty.
        // The reconnectable client starts a fresh connection from connect().
    }

    public func send(
        _ message: DrawingMessage
    ) async throws {
        guard let connection = currentConnection() else {
            throw DrawingNetworkTransportError.notConnected
        }

        do {
            try await connection.send(
                message
            )
        } catch {
            clearConnection(
                connection
            )

            throw error
        }
    }

    public func close() {
        let connection = takeConnection()

        connection?.close()
    }

    public func connect() async throws {
        let nextConnection = try DrawingNetworkMessageConnection(
            host: host,
            port: port
        )

        replaceConnection(
            nextConnection
        )

        do {
            try await nextConnection.startAndWaitUntilReady()
        } catch {
            clearConnection(
                nextConnection
            )

            throw error
        }
    }
}

private extension DrawingNetworkPadClient {
    func currentConnection() -> DrawingNetworkMessageConnection? {
        lock.lock()
        defer {
            lock.unlock()
        }

        return connection
    }

    func replaceConnection(
        _ nextConnection: DrawingNetworkMessageConnection
    ) {
        let previousConnection: DrawingNetworkMessageConnection?

        lock.lock()
        previousConnection = connection
        connection = nextConnection
        lock.unlock()

        previousConnection?.close()
    }

    func takeConnection() -> DrawingNetworkMessageConnection? {
        lock.lock()
        defer {
            lock.unlock()
        }

        let currentConnection = connection
        connection = nil

        return currentConnection
    }

    func clearConnection(
        _ failedConnection: DrawingNetworkMessageConnection
    ) {
        lock.lock()

        let shouldClear = connection === failedConnection

        if shouldClear {
            connection = nil
        }

        lock.unlock()

        if shouldClear {
            failedConnection.close()
        }
    }
}
