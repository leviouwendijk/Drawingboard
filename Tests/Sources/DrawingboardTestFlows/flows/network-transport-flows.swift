import DrawingboardCore
import DrawingboardNetworkTransport
import DrawingboardProtocol
import TestFlows

let networkTransportFlow = TestFlow(
    "transport.network",
    title: "Network transport"
) {
    let port: UInt16 = 47_781
    let server = try DrawingNetworkHostServer(
        port: port
    )

    let connections = server.start()

    let serverTask = Task {
        var connectionIterator = connections.makeAsyncIterator()

        guard let connection = try await connectionIterator.next() else {
            throw DrawingNetworkTransportError.missingMessage
        }

        var messageIterator = connection.messages().makeAsyncIterator()

        guard let message = try await messageIterator.next() else {
            throw DrawingNetworkTransportError.missingMessage
        }

        connection.close()

        return message
    }

    try await Task.sleep(
        nanoseconds: 100_000_000
    )

    let client = try DrawingNetworkPadClient(
        host: "127.0.0.1",
        port: port
    )

    client.start()

    defer {
        client.close()
        server.cancel()
    }

    let page = DrawingPageIdentifier(
        "page-1"
    )
    let tool = try DrawingTool(
        kind: .pen,
        color: .black,
        width: 4
    )
    let message = DrawingMessage.event(
        .stroke_began(
            try DrawingStroke(
                id: DrawingStrokeIdentifier(
                    "stroke-1"
                ),
                page: page,
                tool: tool,
                points: [
                    DrawingPoint(
                        x: 10,
                        y: 20,
                        time: 0
                    ),
                ]
            )
        )
    )

    try await client.send(
        message
    )

    let received = try await serverTask.value

    try Expect.equal(
        received,
        message,
        "network transport sends DrawingMessage over TCP"
    )

    return []
}
