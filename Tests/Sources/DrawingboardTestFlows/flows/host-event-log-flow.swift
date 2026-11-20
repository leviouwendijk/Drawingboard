import DrawingboardCore
import DrawingboardHostRuntime
import DrawingboardProtocol
import TestFlows

let hostEventLogFlow = TestFlow(
    "host.event-log",
    title: "Host event log"
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

    let host = DrawingHostRuntime(
        document: document
    )

    try await host.apply(
        .event(
            .stroke_began(
                try DrawingStroke(
                    id: stroke,
                    page: page,
                    tool: tool,
                    points: [
                        DrawingPoint(
                            x: 10,
                            y: 10,
                            time: 0
                        ),
                    ]
                )
            )
        ),
        time: 0
    )

    try await host.apply(
        .event(
            .stroke_moved(
                DrawingStrokeMove(
                    stroke: stroke,
                    points: [
                        DrawingPoint(
                            x: 20,
                            y: 20,
                            time: 0.01
                        ),
                    ]
                )
            )
        ),
        time: 0.01
    )

    try await host.apply(
        .event(
            .stroke_ended(
                DrawingStrokeEnd(
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
        ),
        time: 0.02
    )

    let snapshot = await host.snapshot()
    let log = await host.eventLog()

    try Expect.equal(
        snapshot.document.pages[0].strokes.count,
        1,
        "host applies events to document state"
    )

    try Expect.equal(
        log.records.count,
        3,
        "host records applied events"
    )

    try Expect.equal(
        log.records[0].sequence,
        0,
        "host event log starts at sequence zero"
    )

    try Expect.equal(
        log.records[2].time,
        0.02,
        "host event log records supplied time"
    )

    let replayed = try DrawingDocumentReplayer().replay(
        log: log,
        from: document
    )

    try Expect.equal(
        replayed,
        snapshot,
        "host event log replays to current snapshot"
    )

    return []
}
