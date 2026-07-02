import DrawingboardCore
import DrawingboardNetworkTransport
import DrawingboardPadNetworkRuntime
import TestFlows

let padNetworkSessionFlow = TestFlow(
    "pad.network-session",
    title: "Pad network session"
) {
    let port: UInt16 = 47_782
    let server = try DrawingNetworkHostServer(
        port: port
    )

    let connections = server.start()

    let serverTask = Task<Int, Error> {
        var connectionIterator = connections.makeAsyncIterator()

        guard let connection = try await connectionIterator.next() else {
            throw DrawingNetworkTransportError.missingMessage
        }

        var messageIterator = connection.messages().makeAsyncIterator()
        var count = 0

        while let _ = try await messageIterator.next() {
            count += 1

            if count == 3 {
                connection.close()
                return count
            }
        }

        throw DrawingNetworkTransportError.missingMessage
    }

    try await Task.sleep(
        nanoseconds: 100_000_000
    )

    let session = try DrawingPadNetworkSession(
        host: "127.0.0.1",
        port: port,
        page: DrawingPageIdentifier(
            "page-1"
        ),
        pageSize: try DrawingSize(
            width: 1280,
            height: 720
        ),
        tool: DrawingTool(
            kind: .pen,
            color: .black,
            width: 5
        ),
        maximumPointCount: 2
    )

    session.start()

    defer {
        session.close()
        server.cancel()
    }

    try await session.runtime.begin(
        stroke: DrawingStrokeIdentifier(
            "stroke-1"
        ),
        at: DrawingPoint(
            x: 10,
            y: 10,
            time: 0
        )
    )

    try await session.runtime.append(
        points: [
            DrawingPoint(
                x: 20,
                y: 20,
                time: 0.01
            ),
            DrawingPoint(
                x: 30,
                y: 30,
                time: 0.02
            ),
        ]
    )

    try await session.runtime.end()

    let receivedMessageCount = try await serverTask.value

    try Expect.equal(
        receivedMessageCount,
        3,
        "pad network session sends begin, move, and end over network"
    )

    return []
}
