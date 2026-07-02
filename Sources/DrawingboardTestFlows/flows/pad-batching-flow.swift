import DrawingboardCore
import DrawingboardHostRuntime
import DrawingboardPadRuntime
import DrawingboardTransport
import TestFlows

enum PadBatchingFlowError: Error {
    case missingMessage
}

let padBatchingFlow = TestFlow(
    "pad.batching",
    title: "Pad stroke batching"
) {
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

    let pair = DrawingLoopbackTransportPair.connected()

    defer {
        Task {
            await pair.close()
        }
    }

    let host = DrawingHostRuntime(
        document: document
    )
    var batcher = try DrawingPadStrokeBatcher(
        page: page,
        tool: tool,
        maximumPointCount: 2
    )

    try await pair.pad.send(
        try batcher.begin(
            stroke: stroke,
            at: DrawingPoint(
                x: 0,
                y: 0,
                time: 0
            )
        )
    )

    let firstAppend = try batcher.append(
        points: [
            DrawingPoint(
                x: 10,
                y: 10,
                time: 0.01
            ),
        ]
    )

    try Expect.equal(
        firstAppend.count,
        0,
        "batcher holds points below threshold"
    )

    let secondAppend = try batcher.append(
        points: [
            DrawingPoint(
                x: 20,
                y: 20,
                time: 0.02
            ),
        ]
    )

    try Expect.equal(
        secondAppend.count,
        1,
        "batcher emits move once threshold is reached"
    )

    for message in secondAppend {
        try await pair.pad.send(
            message
        )
    }

    let endMessages = try batcher.end(
        stroke: stroke,
        points: [
            DrawingPoint(
                x: 30,
                y: 30,
                time: 0.03
            ),
            DrawingPoint(
                x: 40,
                y: 40,
                time: 0.04
            ),
        ]
    )

    try Expect.equal(
        endMessages.count,
        1,
        "batcher emits final end message"
    )

    for message in endMessages {
        try await pair.pad.send(
            message
        )
    }

    var hostIterator = pair.host.messages().makeAsyncIterator()

    for _ in 0..<3 {
        guard let message = try await hostIterator.next() else {
            throw PadBatchingFlowError.missingMessage
        }

        try await host.apply(
            message
        )
    }

    let snapshot = await host.snapshot()

    try Expect.equal(
        snapshot.document.pages[0].strokes.count,
        1,
        "batched stroke is applied to host"
    )

    try Expect.equal(
        snapshot.document.pages[0].strokes[0].points.count,
        5,
        "batched stroke preserves all points"
    )

    return []
}
