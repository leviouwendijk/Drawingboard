import AppKit
import DrawingboardCore
import DrawingboardHostRuntime
import DrawingboardPadRuntime
import DrawingboardProtocol
import DrawingboardRendering
import DrawingboardTransport
import Foundation

@MainActor
@main
final class DrawingboardHostProbe: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var demoTask: Task<Void, Never>?

    static func main() {
        let application = NSApplication.shared
        let delegate = DrawingboardHostProbe()

        application.delegate = delegate
        application.setActivationPolicy(
            .regular
        )
        application.activate(
            ignoringOtherApps: true
        )
        application.run()
    }

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        do {
            let seed = try Self.makeSeed()
            let initialFrame = try Self.renderFrame(
                state: DrawingDocumentState(
                    document: seed.document
                ),
                pageSize: seed.pageSize,
                viewSize: seed.viewSize
            )

            let view = DrawingboardHostProbeView(
                frame: NSRect(
                    x: 0,
                    y: 0,
                    width: seed.viewSize.width,
                    height: seed.viewSize.height
                ),
                renderFrame: initialFrame
            )

            let window = NSWindow(
                contentRect: view.frame,
                styleMask: [
                    .titled,
                    .closable,
                    .miniaturizable,
                    .resizable,
                ],
                backing: .buffered,
                defer: false
            )

            window.title = "Drawingboard Host Probe"
            window.contentView = view
            window.center()
            window.makeKeyAndOrderFront(
                nil
            )

            self.window = window

            demoTask = Task { @MainActor in
                do {
                    try await Self.runLoopbackDemo(
                        seed: seed,
                        view: view
                    )
                } catch is CancellationError {
                    return
                } catch {
                    fputs(
                        "DrawingboardHostProbe demo failed: \(error.localizedDescription)\n",
                        stderr
                    )
                }
            }
        } catch {
            fputs(
                "DrawingboardHostProbe failed: \(error.localizedDescription)\n",
                stderr
            )
            NSApplication.shared.terminate(
                nil
            )
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        true
    }

    func applicationWillTerminate(
        _ notification: Notification
    ) {
        demoTask?.cancel()
    }
}

private struct DrawingboardHostProbeSeed: Sendable {
    let pageSize: DrawingSize
    let viewSize: DrawingSize
    let page: DrawingPageIdentifier
    let document: DrawingDocument
    let tool: DrawingTool
}

private enum DrawingboardHostProbeError: Error {
    case missingHostMessage
}

private extension DrawingboardHostProbe {
    static func recordingOutputDirectoryURL() -> URL {
        URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    }

    static func makeSeed() throws -> DrawingboardHostProbeSeed {
        let pageSize = try DrawingSize(
            width: 1280,
            height: 720
        )
        let viewSize = try DrawingSize(
            width: 960,
            height: 540
        )
        let page = DrawingPageIdentifier(
            "probe-page"
        )
        let document = try DrawingDocument.blank(
            page: page,
            size: pageSize
        )
        let tool = try DrawingTool(
            kind: .pen,
            color: .black,
            width: 5
        )

        return DrawingboardHostProbeSeed(
            pageSize: pageSize,
            viewSize: viewSize,
            page: page,
            document: document,
            tool: tool
        )
    }

    static func renderFrame(
        state: DrawingDocumentState,
        pageSize: DrawingSize,
        viewSize: DrawingSize
    ) throws -> DrawingRenderFrame {
        let viewport = try DrawingViewport.fitPage(
            pageSize: pageSize,
            viewSize: viewSize,
            margin: 24
        )

        return try DrawingRenderCommandResolver().resolve(
            state: state,
            viewport: viewport
        )
    }

    static func runLoopbackDemo(
        seed: DrawingboardHostProbeSeed,
        view: DrawingboardHostProbeView
    ) async throws {
        let pair = DrawingLoopbackTransportPair.connected()
        let host = DrawingHostRuntime(
            document: seed.document
        )

        let outputDirectory = recordingOutputDirectoryURL()
        let eventLogURL = outputDirectory.appendingPathComponent(
            "drawingboard-events.jsonl"
        )
        let manifestURL = outputDirectory.appendingPathComponent(
            "drawingboard-manifest.json"
        )
        let eventLogStore = DrawingEventLogStore()

        try eventLogStore.reset(
            at: eventLogURL
        )

        let receiver = Task { @MainActor in
            do {
                var iterator = pair.host.messages().makeAsyncIterator()

                while let message = try await iterator.next() {
                    if let record = try await host.apply(
                        message
                    ) {
                        try eventLogStore.append(
                            record,
                            to: eventLogURL
                        )
                    }
                    let snapshot = await host.snapshot()
                    let frame = try Self.renderFrame(
                        state: snapshot,
                        pageSize: seed.pageSize,
                        viewSize: seed.viewSize
                    )

                    view.update(
                        renderFrame: frame
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                fputs(
                    "DrawingboardHostProbe receiver failed: \(error.localizedDescription)\n",
                    stderr
                )
            }
        }

        defer {
            receiver.cancel()
        }

        var batcher = try DrawingPadStrokeBatcher(
            page: seed.page,
            tool: seed.tool,
            maximumPointCount: 2
        )

        let stroke = DrawingStrokeIdentifier(
            "live-probe-stroke"
        )

        try await send(
            [
                try batcher.begin(
                    stroke: stroke,
                    at: DrawingPoint(
                        x: 120,
                        y: 140,
                        time: 0
                    )
                ),
            ],
            through: pair.pad
        )

        try await send(
            try batcher.append(
                points: [
                    DrawingPoint(
                        x: 220,
                        y: 180,
                        time: 0.01
                    ),
                ]
            ),
            through: pair.pad
        )

        try await send(
            try batcher.append(
                points: [
                    DrawingPoint(
                        x: 320,
                        y: 120,
                        time: 0.02
                    ),
                ]
            ),
            through: pair.pad
        )

        try await send(
            try batcher.append(
                points: [
                    DrawingPoint(
                        x: 440,
                        y: 260,
                        time: 0.03
                    ),
                ]
            ),
            through: pair.pad
        )

        try await send(
            try batcher.append(
                points: [
                    DrawingPoint(
                        x: 620,
                        y: 220,
                        time: 0.04
                    ),
                ]
            ),
            through: pair.pad
        )

        try await send(
            try batcher.append(
                points: [
                    DrawingPoint(
                        x: 760,
                        y: 360,
                        time: 0.05
                    ),
                ]
            ),
            through: pair.pad
        )

        try await send(
            try batcher.end(
                stroke: stroke,
                points: [
                    DrawingPoint(
                        x: 920,
                        y: 300,
                        time: 0.06
                    ),
                    DrawingPoint(
                        x: 1040,
                        y: 380,
                        time: 0.07
                    ),
                ]
            ),
            through: pair.pad
        )

        try await Task.sleep(
            nanoseconds: 300_000_000
        )

        await pair.close()
        await receiver.value

        let log = await host.eventLog()

        try DrawingRecordingManifestStore().write(
            DrawingRecordingManifest(
                document: seed.document.id,
                activePage: seed.page,
                pageSize: seed.pageSize,
                eventLogFile: eventLogURL.lastPathComponent
            ),
            to: manifestURL
        )

        print(
            "DrawingboardHostProbe wrote \(log.records.count) events to \(eventLogURL.path)"
        )
        print(
            "DrawingboardHostProbe wrote manifest to \(manifestURL.path)"
        )
    }

    static func send(
        _ messages: [DrawingMessage],
        through endpoint: DrawingLoopbackTransportEndpoint
    ) async throws {
        for message in messages {
            try await endpoint.send(
                message
            )

            try await Task.sleep(
                nanoseconds: 180_000_000
            )
        }
    }
}
