import DrawingboardCore
import DrawingboardPadRuntime
import DrawingboardProtocol
import TestFlows

private actor DrawingPadAppRuntimeMessageCollector {
    private var messages: [DrawingMessage] = []

    func append(
        _ message: DrawingMessage
    ) {
        messages.append(
            message
        )
    }

    func snapshot() -> [DrawingMessage] {
        messages
    }
}

let padAppRuntimeFlow = TestFlow(
    "pad.app-runtime",
    title: "Pad app runtime"
) {
    let page = DrawingPageIdentifier(
        "page-1"
    )
    let tool = try DrawingTool(
        kind: .pen,
        color: .black,
        width: 4
    )
    let collector = DrawingPadAppRuntimeMessageCollector()

    let runtime = try DrawingPadAppRuntime(
        page: page,
        tool: tool,
        maximumPointCount: 2
    ) { message in
        await collector.append(
            message
        )
    }

    try await runtime.begin(
        stroke: DrawingStrokeIdentifier(
            "stroke-1"
        ),
        at: DrawingPoint(
            x: 10,
            y: 10,
            time: 0
        )
    )

    try await runtime.append(
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

    try await runtime.end()

    let messages = await collector.snapshot()

    try Expect.equal(
        messages.count,
        3,
        "pad app runtime emits begin, batched move, and end"
    )

    guard case .event(.stroke_began) = messages[0] else {
        throw DrawingPadStrokeBatcherError.missingOpenStroke
    }

    guard case .event(.stroke_moved(let move)) = messages[1] else {
        throw DrawingPadStrokeBatcherError.missingOpenStroke
    }

    try Expect.equal(
        move.points.count,
        2,
        "pad app runtime emits batched move points"
    )

    guard case .event(.stroke_ended) = messages[2] else {
        throw DrawingPadStrokeBatcherError.missingOpenStroke
    }

    return []
}
