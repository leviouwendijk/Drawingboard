import AppKit
import DrawingboardCore
import DrawingboardHostRuntime
import DrawingboardNetworkTransport
import DrawingboardProtocol
import DrawingboardRendering
import Foundation

@MainActor
@main
final class DrawingboardHostNetworkProbe: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var networkTask: Task<Void, Never>?
    private var server: DrawingNetworkHostServer?

    static func main() {
        let application = NSApplication.shared
        let delegate = DrawingboardHostNetworkProbe()

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
            let host = DrawingHostRuntime(
                document: seed.document
            )
            let initialFrame = try Self.renderFrame(
                state: DrawingDocumentState(
                    document: seed.document
                ),
                pageSize: seed.pageSize,
                viewSize: seed.viewSize
            )
            let view = DrawingboardHostNetworkProbeView(
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

            window.title = "Drawingboard Network Host"
            window.contentView = view
            window.center()
            window.makeKeyAndOrderFront(
                nil
            )

            self.window = window

            let port: UInt16 = 47_777
            let server = try DrawingNetworkHostServer(
                port: port
            )
            self.server = server

            print(
                "DrawingboardHostNetworkProbe listening on TCP port \(port)"
            )

            networkTask = Task { @MainActor in
                do {
                    try await Self.runServer(
                        server: server,
                        host: host,
                        seed: seed,
                        view: view
                    )
                } catch is CancellationError {
                    return
                } catch {
                    fputs(
                        "DrawingboardHostNetworkProbe failed: \(error.localizedDescription)\n",
                        stderr
                    )
                }
            }
        } catch {
            fputs(
                "DrawingboardHostNetworkProbe launch failed: \(error.localizedDescription)\n",
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
        networkTask?.cancel()
        server?.cancel()
    }
}

private struct DrawingboardHostNetworkProbeSeed: Sendable {
    let pageSize: DrawingSize
    let viewSize: DrawingSize
    let page: DrawingPageIdentifier
    let document: DrawingDocument
}

private extension DrawingboardHostNetworkProbe {
    static func makeSeed() throws -> DrawingboardHostNetworkProbeSeed {
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

        return DrawingboardHostNetworkProbeSeed(
            pageSize: pageSize,
            viewSize: viewSize,
            page: page,
            document: document
        )
    }

    static func runServer(
        server: DrawingNetworkHostServer,
        host: DrawingHostRuntime,
        seed: DrawingboardHostNetworkProbeSeed,
        view: DrawingboardHostNetworkProbeView
    ) async throws {
        var connectionIterator = server.start().makeAsyncIterator()

        while let connection = try await connectionIterator.next() {
            print(
                "DrawingboardHostNetworkProbe accepted connection"
            )

            var messageIterator = connection.messages().makeAsyncIterator()

            while let message = try await messageIterator.next() {
                try await host.apply(
                    message
                )

                let snapshot = await host.snapshot()
                let frame = try renderFrame(
                    state: snapshot,
                    pageSize: seed.pageSize,
                    viewSize: seed.viewSize
                )

                view.update(
                    renderFrame: frame
                )
            }

            print(
                "DrawingboardHostNetworkProbe connection ended"
            )
        }
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
