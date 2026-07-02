import DrawingboardCore
import TestFlows

let eventLogTimingFlow = TestFlow(
    "event-log.timing",
    title: "Event log timing"
) {
    let page = DrawingPageIdentifier(
        "page-1"
    )
    let tool = try DrawingTool(
        kind: .pen,
        color: .black,
        width: 4
    )
    let stroke = DrawingStrokeIdentifier(
        "stroke-1"
    )

    let records = [
        DrawingEventRecord(
            sequence: 0,
            time: 10,
            event: .stroke_began(
                try DrawingStroke(
                    id: stroke,
                    page: page,
                    tool: tool,
                    points: [
                        DrawingPoint(
                            x: 1,
                            y: 1,
                            time: 0
                        ),
                    ]
                )
            )
        ),
        DrawingEventRecord(
            sequence: 1,
            time: 10.25,
            event: .stroke_moved(
                DrawingStrokeMove(
                    stroke: stroke,
                    points: [
                        DrawingPoint(
                            x: 2,
                            y: 2,
                            time: 0.01
                        ),
                    ]
                )
            )
        ),
        DrawingEventRecord(
            sequence: 2,
            time: 11,
            event: .stroke_ended(
                DrawingStrokeEnd(
                    stroke: stroke,
                    points: [
                        DrawingPoint(
                            x: 3,
                            y: 3,
                            time: 0.02
                        ),
                    ]
                )
            )
        ),
    ]

    let log = try DrawingEventLog(
        records: records
    )

    let delays = zip(
        log.records,
        log.records.dropFirst()
    ).map { previous, next in
        next.time - previous.time
    }

    try Expect.equal(
        delays,
        [
            0.25,
            0.75,
        ],
        "event log timing deltas derive from record timestamps"
    )

    return []
}
