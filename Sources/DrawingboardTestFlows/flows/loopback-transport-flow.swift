import DrawingboardCore
import DrawingboardHostRuntime
import DrawingboardPadRuntime
import DrawingboardProtocol
import DrawingboardTransport
import TestFlows

enum LoopbackTransportFlowError: Error {
    case missingMessage
}

let loopbackTransportFlow = TestFlow(
    "transport.loopback",
    title: "Loopback transport"
) {
    let pair = DrawingLoopbackTransportPair.connected()

    defer {
        Task {
            await pair.close()
        }
    }

    let hello = DrawingMessage.hello(
        DrawingHello(
            role: .pad,
            deviceName: "iPad Mini"
        )
    )

    try await pair.pad.send(
        hello
    )

    var hostIterator = pair.host.messages().makeAsyncIterator()

    guard let receivedHello = try await hostIterator.next() else {
        throw LoopbackTransportFlowError.missingMessage
    }

    try Expect.equal(
        receivedHello,
        hello,
        "host receives message sent by pad"
    )

    let size = try DrawingSize(
        width: 1280,
        height: 720
    )
    let page = DrawingPageIdentifier(
        "page-1"
    )
    let document = try DrawingDocument.blank(
        page: page,
        size: size
    )
    let tool = try DrawingTool(
        kind: .pen,
        color: .black,
        width: 4
    )
    let stroke = DrawingStrokeIdentifier(
        "stroke-1"
    )

    let host = DrawingHostRuntime(
        document: document
    )
    let pad = DrawingPadRuntime(
        page: page,
        tool: tool
    )

    try await pair.pad.send(
        try pad.begin(
            stroke: stroke,
            at: DrawingPoint(
                x: 1,
                y: 2,
                time: 0
            )
        )
    )

    try await pair.pad.send(
        pad.move(
            stroke: stroke,
            points: [
                DrawingPoint(
                    x: 10,
                    y: 20,
                    time: 0.01
                ),
            ]
        )
    )

    try await pair.pad.send(
        pad.end(
            stroke: stroke,
            points: [
                DrawingPoint(
                    x: 30,
                    y: 40,
                    time: 0.02
                ),
            ]
        )
    )

    for _ in 0..<3 {
        guard let message = try await hostIterator.next() else {
            throw LoopbackTransportFlowError.missingMessage
        }

        try await host.apply(
            message
        )
    }

    let snapshot = await host.snapshot()

    try Expect.equal(
        snapshot.document.pages[0].strokes.count,
        1,
        "transported stroke is applied to host"
    )

    try Expect.equal(
        snapshot.document.pages[0].strokes[0].points.count,
        3,
        "transport preserves stroke point stream"
    )

    return []
}
