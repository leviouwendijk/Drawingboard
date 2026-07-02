import AppKit
import DrawingboardCore
import DrawingboardProtocol
import DrawingboardRendering
import Foundation

@MainActor
@main
final class DrawingboardReplayProbe: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var replayTask: Task<Void, Never>?

    static func main() {
        let application = NSApplication.shared
        let delegate = DrawingboardReplayProbe()

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
            let input = try Self.resolveInput()
            let session = try Self.loadSession(
                manifestURL: input.manifestURL,
                viewSize: input.viewSize
            )

            let initialFrame = try Self.renderFrame(
                state: DrawingDocumentState(
                    document: session.document
                ),
                pageSize: session.manifest.pageSize,
                viewSize: input.viewSize
            )

            let view = DrawingboardReplayProbeView(
                frame: NSRect(
                    x: 0,
                    y: 0,
                    width: input.viewSize.width,
                    height: input.viewSize.height
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

            window.title = "Drawingboard Replay Probe"
            window.contentView = view
            window.center()
            window.makeKeyAndOrderFront(
                nil
            )

            self.window = window

            print(
                "DrawingboardReplayProbe loaded \(input.manifestURL.path)"
            )

            replayTask = Task { @MainActor in
                do {
                    try await Self.runAnimatedReplay(
                        session: session,
                        viewSize: input.viewSize,
                        view: view
                    )
                } catch is CancellationError {
                    return
                } catch {
                    fputs(
                        "DrawingboardReplayProbe replay failed: \(error.localizedDescription)\n",
                        stderr
                    )
                }
            }
        } catch {
            fputs(
                "DrawingboardReplayProbe failed: \(error.localizedDescription)\n",
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
        replayTask?.cancel()
    }
}

private struct DrawingboardReplayInput: Sendable {
    let manifestURL: URL
    let viewSize: DrawingSize
}

private struct DrawingboardReplaySession: Sendable {
    let manifest: DrawingRecordingManifest
    let document: DrawingDocument
    let log: DrawingEventLog
}

private extension DrawingboardReplayProbe {
    static func resolveInput() throws -> DrawingboardReplayInput {
        let arguments = CommandLine.arguments.dropFirst()

        let manifestPath = arguments.first.map {
            URL(
                fileURLWithPath: $0
            )
        } ?? URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
        .appendingPathComponent(
            "drawingboard-manifest.json"
        )

        return DrawingboardReplayInput(
            manifestURL: manifestPath,
            viewSize: try DrawingSize(
                width: 960,
                height: 540
            )
        )
    }

    static func loadSession(
        manifestURL: URL,
        viewSize: DrawingSize
    ) throws -> DrawingboardReplaySession {
        let manifest = try DrawingRecordingManifestStore().read(
            from: manifestURL
        )

        let recordingDirectory = manifestURL
            .deletingLastPathComponent()

        let eventLogURL = recordingDirectory
            .appendingPathComponent(
                manifest.eventLogFile
            )

        let log = try DrawingEventLogStore().read(
            from: eventLogURL
        )

        let page = DrawingPage(
            id: manifest.activePage,
            size: manifest.pageSize
        )

        let document = try DrawingDocument(
            id: manifest.document,
            pages: [
                page,
            ],
            activePage: manifest.activePage
        )

        return DrawingboardReplaySession(
            manifest: manifest,
            document: document,
            log: log
        )
    }

    static func runAnimatedReplay(
        session: DrawingboardReplaySession,
        viewSize: DrawingSize,
        view: DrawingboardReplayProbeView
    ) async throws {
        var state = DrawingDocumentState(
            document: session.document
        )
        let reducer = DrawingDocumentReducer()

        var previousTime: TimeInterval?

        for record in session.log.records {
            try Task.checkCancellation()

            if let previousTime {
                let delay = max(
                    0,
                    record.time - previousTime
                )

                try await Task.sleep(
                    nanoseconds: UInt64(
                        delay * 1_000_000_000
                    )
                )
            }

            try reducer.apply(
                record.event,
                to: &state
            )

            let frame = try renderFrame(
                state: state,
                pageSize: session.manifest.pageSize,
                viewSize: viewSize
            )

            view.update(
                renderFrame: frame
            )

            previousTime = record.time
        }

        print(
            "DrawingboardReplayProbe replayed \(session.log.records.count) events"
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
}
