import DrawingboardCore
import DrawingboardProtocol
import Foundation
import TestFlows

let eventLogStoreFlow = TestFlow(
    "event-log.store",
    title: "Event log store"
) {
    let size = try DrawingSize(
        width: 800,
        height: 600
    )
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
        .stroke_ended(
            DrawingStrokeEnd(
                stroke: stroke,
                points: [
                    DrawingPoint(
                        x: 20,
                        y: 20,
                        time: 0.01
                    ),
                ]
            )
        ),
        time: 0.01
    )

    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "drawingboard-\(UUID().uuidString).jsonl"
        )

    defer {
        try? FileManager.default.removeItem(
            at: url
        )
    }

    let store = DrawingEventLogStore()

    try store.write(
        log,
        to: url
    )

    let loaded = try store.read(
        from: url
    )

    try Expect.equal(
        loaded.records,
        log.records,
        "event log survives file store roundtrip"
    )

    let document = try DrawingDocument.blank(
        page: page,
        size: size
    )

    let replayed = try DrawingDocumentReplayer().replay(
        log: loaded,
        from: document
    )

    try Expect.equal(
        replayed.document.pages[0].strokes.count,
        1,
        "stored event log replays into document state"
    )

    return []
}
