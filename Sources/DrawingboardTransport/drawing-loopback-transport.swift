import DrawingboardProtocol
import Foundation

actor DrawingLoopbackMailbox {
    private var queued: [DrawingMessage]
    private var waiters: [CheckedContinuation<DrawingMessage?, Never>]
    private var isFinished: Bool

    init() {
        self.queued = []
        self.waiters = []
        self.isFinished = false
    }

    func emit(
        _ message: DrawingMessage
    ) {
        guard !isFinished else {
            return
        }

        if waiters.isEmpty {
            queued.append(
                message
            )
            return
        }

        let waiter = waiters.removeFirst()
        waiter.resume(
            returning: message
        )
    }

    func finish() {
        guard !isFinished else {
            return
        }

        isFinished = true

        let pending = waiters
        waiters.removeAll()

        for waiter in pending {
            waiter.resume(
                returning: nil
            )
        }
    }

    nonisolated func messages() -> AsyncThrowingStream<DrawingMessage, Error> {
        AsyncThrowingStream {
            await self.next()
        }
    }

    private func next() async -> DrawingMessage? {
        if !queued.isEmpty {
            return queued.removeFirst()
        }

        if isFinished {
            return nil
        }

        return await withCheckedContinuation { continuation in
            waiters.append(
                continuation
            )
        }
    }
}

public final class DrawingLoopbackTransportEndpoint: DrawingMessageTransport, Sendable {
    private let inbound: DrawingLoopbackMailbox
    private let outbound: DrawingLoopbackMailbox

    init(
        inbound: DrawingLoopbackMailbox,
        outbound: DrawingLoopbackMailbox
    ) {
        self.inbound = inbound
        self.outbound = outbound
    }

    public func send(
        _ message: DrawingMessage
    ) async throws {
        await outbound.emit(
            message
        )
    }

    public func messages() -> AsyncThrowingStream<DrawingMessage, Error> {
        inbound.messages()
    }

    public func close() async {
        await inbound.finish()
    }
}

public struct DrawingLoopbackTransportPair: Sendable {
    public let host: DrawingLoopbackTransportEndpoint
    public let pad: DrawingLoopbackTransportEndpoint

    public init(
        host: DrawingLoopbackTransportEndpoint,
        pad: DrawingLoopbackTransportEndpoint
    ) {
        self.host = host
        self.pad = pad
    }

    public static func connected() -> DrawingLoopbackTransportPair {
        let hostInbound = DrawingLoopbackMailbox()
        let padInbound = DrawingLoopbackMailbox()

        return DrawingLoopbackTransportPair(
            host: DrawingLoopbackTransportEndpoint(
                inbound: hostInbound,
                outbound: padInbound
            ),
            pad: DrawingLoopbackTransportEndpoint(
                inbound: padInbound,
                outbound: hostInbound
            )
        )
    }

    public func close() async {
        await host.close()
        await pad.close()
    }
}
