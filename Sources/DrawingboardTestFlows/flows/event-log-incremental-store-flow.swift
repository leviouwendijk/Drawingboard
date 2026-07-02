import DrawingboardCore
import DrawingboardProtocol
import Foundation
import TestFlows

let eventLogIncrementalStoreFlow = TestFlow(
    "event-log.incremental-store",
    title: "Event log incremental store"
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

    var log = DrawingEventLog()

    let first = try log.append(
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

    let second = try log.append(
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
        ),
        time: 0.01
    )

    let third = try log.append(
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
        ),
        time: 0.02
    )

    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "drawingboard-incremental-\(UUID().uuidString).jsonl"
        )

    defer {
        try? FileManager.default.removeItem(
            at: url
        )
    }

    let store = DrawingEventLogStore()

    try store.reset(
        at: url
    )
    try store.append(
        first,
        to: url
    )
    try store.append(
        second,
        to: url
    )
    try store.append(
        third,
        to: url
    )

    let loaded = try store.read(
        from: url
    )

    try Expect.equal(
        loaded.records,
        log.records,
        "incremental event log append matches in-memory log"
    )

    return []
}
