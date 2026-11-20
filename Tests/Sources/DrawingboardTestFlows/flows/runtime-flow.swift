import DrawingboardCore
import DrawingboardHostRuntime
import DrawingboardPadRuntime
import TestFlows

let runtimeFlow = TestFlow(
    "runtime.host-pad",
    title: "Host and pad runtime"
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
        width: 5
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

    try await host.apply(
        try pad.begin(
            stroke: stroke,
            at: DrawingPoint(
                x: 1,
                y: 2,
                time: 0
            )
        )
    )

    try await host.apply(
        pad.move(
            stroke: stroke,
            points: [
                DrawingPoint(
                    x: 4,
                    y: 8,
                    time: 0.01
                ),
            ]
        )
    )

    try await host.apply(
        pad.end(
            stroke: stroke,
            points: [
                DrawingPoint(
                    x: 10,
                    y: 12,
                    time: 0.02
                ),
            ]
        )
    )

    let snapshot = await host.snapshot()

    try Expect.equal(
        snapshot.document.pages[0].strokes.count,
        1,
        "host receives pad stroke"
    )
    try Expect.equal(
        snapshot.document.pages[0].strokes[0].points.count,
        3,
        "host stores all streamed points"
    )

    return []
}
