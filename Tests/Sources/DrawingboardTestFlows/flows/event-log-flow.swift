import DrawingboardCore
import DrawingboardProtocol
import TestFlows

let eventLogFlow = TestFlow(
    "event-log.replay",
    title: "Event log replay"
) {
    let size = try DrawingSize(
        width: 800,
        height: 600
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

    var log = DrawingEventLog()

    try log.append(
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
        ),
        time: 0
    )

    try log.append(
        .stroke_moved(
            DrawingStrokeMove(
                stroke: stroke,
                points: [
                    DrawingPoint(
                        x: 20,
                        y: 20,
                        time: 0.01
                    ),
                    DrawingPoint(
                        x: 30,
                        y: 40,
                        time: 0.02
                    ),
                ]
            )
        ),
        time: 0.02
    )

    try log.append(
        .stroke_ended(
            DrawingStrokeEnd(
                stroke: stroke,
                points: [
                    DrawingPoint(
                        x: 50,
                        y: 60,
                        time: 0.03
                    ),
                ]
            )
        ),
        time: 0.03
    )

    try Expect.equal(
        log.records.count,
        3,
        "event log stores records"
    )

    try Expect.equal(
        log.records[0].sequence,
        0,
        "first record sequence is zero"
    )

    try Expect.equal(
        log.records[2].sequence,
        2,
        "event record sequence increments"
    )

    let codec = DrawingEventRecordCodec()
    let data = try codec.encodeLog(
        log
    )
    let decoded = try codec.decodeLog(
        data
    )

    try Expect.equal(
        decoded.records,
        log.records,
        "event log survives JSONL roundtrip"
    )

    let replayer = DrawingDocumentReplayer()
    let state = try replayer.replay(
        log: decoded,
        from: document
    )

    try Expect.equal(
        state.document.pages[0].strokes.count,
        1,
        "replay produces finished stroke"
    )

    try Expect.equal(
        state.document.pages[0].strokes[0].points.count,
        4,
        "replay preserves streamed stroke points"
    )

    return []
}
