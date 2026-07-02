import DrawingboardCore
import DrawingboardProtocol
import DrawingboardRendering
import Foundation
import TestFlows

let recordingReplayFlow = TestFlow(
    "recording.replay",
    title: "Recording replay"
) {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "drawingboard-replay-\(UUID().uuidString)",
            isDirectory: true
        )

    try FileManager.default.createDirectory(
        at: temporaryDirectory,
        withIntermediateDirectories: true
    )

    defer {
        try? FileManager.default.removeItem(
            at: temporaryDirectory
        )
    }

    let pageSize = try DrawingSize(
        width: 1280,
        height: 720
    )
    let pageID = DrawingPageIdentifier(
        "page-1"
    )
    let documentID = DrawingDocumentIdentifier(
        "document-1"
    )
    let tool = try DrawingTool(
        kind: .pen,
        color: .black,
        width: 5
    )
    let strokeID = DrawingStrokeIdentifier(
        "stroke-1"
    )

    var log = DrawingEventLog()

    try log.append(
        .stroke_began(
            try DrawingStroke(
                id: strokeID,
                page: pageID,
                tool: tool,
                points: [
                    DrawingPoint(
                        x: 120,
                        y: 140,
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
                stroke: strokeID,
                points: [
                    DrawingPoint(
                        x: 220,
                        y: 180,
                        time: 0.01
                    ),
                    DrawingPoint(
                        x: 320,
                        y: 120,
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
                stroke: strokeID,
                points: [
                    DrawingPoint(
                        x: 420,
                        y: 220,
                        time: 0.03
                    ),
                ]
            )
        ),
        time: 0.03
    )

    let eventLogURL = temporaryDirectory.appendingPathComponent(
        "drawingboard-events.jsonl"
    )
    let manifestURL = temporaryDirectory.appendingPathComponent(
        "drawingboard-manifest.json"
    )

    try DrawingEventLogStore().write(
        log,
        to: eventLogURL
    )

    try DrawingRecordingManifestStore().write(
        DrawingRecordingManifest(
            document: documentID,
            activePage: pageID,
            pageSize: pageSize,
            eventLogFile: eventLogURL.lastPathComponent
        ),
        to: manifestURL
    )

    let manifest = try DrawingRecordingManifestStore().read(
        from: manifestURL
    )
    let loadedLog = try DrawingEventLogStore().read(
        from: temporaryDirectory.appendingPathComponent(
            manifest.eventLogFile
        )
    )

    let document = try DrawingDocument(
        id: manifest.document,
        pages: [
            DrawingPage(
                id: manifest.activePage,
                size: manifest.pageSize
            ),
        ],
        activePage: manifest.activePage
    )

    let state = try DrawingDocumentReplayer().replay(
        log: loadedLog,
        from: document
    )

    let viewport = try DrawingViewport.fitPage(
        pageSize: manifest.pageSize,
        viewSize: try DrawingSize(
            width: 960,
            height: 540
        ),
        margin: 24
    )

    let frame = try DrawingRenderCommandResolver().resolve(
        state: state,
        viewport: viewport
    )

    try Expect.equal(
        state.document.id,
        documentID,
        "recording replay restores document identity"
    )

    try Expect.equal(
        state.document.pages[0].strokes.count,
        1,
        "recording replay restores stroke"
    )

    try Expect.equal(
        frame.commands.count,
        1,
        "recording replay resolves render commands"
    )

    return []
}
