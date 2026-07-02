import DrawingboardCore
import DrawingboardProtocol
import Foundation
import TestFlows

let recordingManifestFlow = TestFlow(
    "recording.manifest",
    title: "Recording manifest"
) {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "drawingboard-recording-\(UUID().uuidString)",
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
    let page = DrawingPageIdentifier(
        "page-1"
    )
    let document = try DrawingDocument.blank(
        page: page,
        size: pageSize
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

    let manifest = DrawingRecordingManifest(
        document: document.id,
        activePage: page,
        pageSize: pageSize,
        eventLogFile: eventLogURL.lastPathComponent
    )

    try DrawingRecordingManifestStore().write(
        manifest,
        to: manifestURL
    )

    let loadedManifest = try DrawingRecordingManifestStore().read(
        from: manifestURL
    )
    let loadedLog = try DrawingEventLogStore().read(
        from: temporaryDirectory.appendingPathComponent(
            loadedManifest.eventLogFile
        )
    )

    let replayDocument = try DrawingDocument.blank(
        page: loadedManifest.activePage,
        size: loadedManifest.pageSize
    )

    let replayed = try DrawingDocumentReplayer().replay(
        log: loadedLog,
        from: replayDocument
    )

    try Expect.equal(
        loadedManifest,
        manifest,
        "recording manifest survives file roundtrip"
    )

    try Expect.equal(
        replayed.document.pages[0].strokes.count,
        1,
        "recording manifest and event log replay together"
    )

    return []
}
