import DrawingboardCore
import DrawingboardNetworkTransport
import DrawingboardPadRuntime
import DrawingboardProtocol
import Foundation

private struct DrawingPadHistoryEntry: Sendable {
    let undo: DrawingEvent
    let redo: DrawingEvent
}

private final class DrawingPadStateBroadcaster: @unchecked Sendable {
    let stream: AsyncStream<DrawingDocumentState>

    private let lock = NSLock()
    private var continuation: AsyncStream<DrawingDocumentState>.Continuation?

    init() {
        var capturedContinuation: AsyncStream<DrawingDocumentState>.Continuation?

        self.stream = AsyncStream { continuation in
            capturedContinuation = continuation
        }

        self.continuation = capturedContinuation
    }

    func yield(
        _ state: DrawingDocumentState
    ) {
        lock.lock()
        let continuation = self.continuation
        lock.unlock()

        continuation?.yield(
            state
        )
    }

    func finish() {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        continuation?.finish()
    }
}

private actor DrawingPadNetworkDocumentMirror {
    private var state: DrawingDocumentState
    private let reducer: DrawingDocumentReducer
    private let broadcaster: DrawingPadStateBroadcaster

    private var undoStack: [DrawingPadHistoryEntry]
    private var redoStack: [DrawingPadHistoryEntry]

    init(
        page: DrawingPageIdentifier,
        pageSize: DrawingSize,
        reducer: DrawingDocumentReducer = DrawingDocumentReducer(),
        broadcaster: DrawingPadStateBroadcaster
    ) throws {
        let document = try DrawingDocument.blank(
            page: page,
            size: pageSize
        )

        self.state = DrawingDocumentState(
            document: document
        )
        self.reducer = reducer
        self.broadcaster = broadcaster
        self.undoStack = []
        self.redoStack = []

        broadcaster.yield(
            state
        )
    }

    func snapshot() -> DrawingDocumentState {
        state
    }

    func applyUser(
        _ message: DrawingMessage
    ) throws {
        switch message {
        case .event(let event):
            try applyUser(
                event
            )

        case .snapshot(let document):
            state = DrawingDocumentState(
                document: document
            )
            undoStack.removeAll()
            redoStack.removeAll()
            publish()

        case .hello,
             .session_accepted:
            break
        }
    }

    func applyUser(
        _ event: DrawingEvent
    ) throws {
        let previousState = state

        try reducer.apply(
            event,
            to: &state
        )

        if let history = historyEntry(
            for: event,
            previousState: previousState,
            currentState: state
        ) {
            undoStack.append(
                history
            )
            redoStack.removeAll()
        }

        publish()
    }

    func makeUndoEvent() throws -> DrawingEvent? {
        guard let entry = undoStack.popLast() else {
            return nil
        }

        try reducer.apply(
            entry.undo,
            to: &state
        )

        redoStack.append(
            entry
        )

        publish()

        return entry.undo
    }

    func makeRedoEvent() throws -> DrawingEvent? {
        guard let entry = redoStack.popLast() else {
            return nil
        }

        try reducer.apply(
            entry.redo,
            to: &state
        )

        undoStack.append(
            entry
        )

        publish()

        return entry.redo
    }
}

private extension DrawingPadNetworkDocumentMirror {
    func publish() {
        broadcaster.yield(
            state
        )
    }

    func historyEntry(
        for event: DrawingEvent,
        previousState: DrawingDocumentState,
        currentState: DrawingDocumentState
    ) -> DrawingPadHistoryEntry? {
        switch event {
        case .stroke_ended(let end):
            guard let stroke = currentState.finishedStroke(
                id: end.stroke
            ) else {
                return nil
            }

            return DrawingPadHistoryEntry(
                undo: .stroke_removed(
                    stroke.id
                ),
                redo: .stroke_restored(
                    stroke
                )
            )

        case .stroke_removed(let id):
            guard let stroke = previousState.finishedStroke(
                id: id
            ) else {
                return nil
            }

            return DrawingPadHistoryEntry(
                undo: .stroke_restored(
                    stroke
                ),
                redo: .stroke_removed(
                    id
                )
            )

        case .page_cleared(let page):
            guard let previousPage = previousState.page(
                id: page
            ) else {
                return nil
            }

            return DrawingPadHistoryEntry(
                undo: .page_restored(
                    previousPage
                ),
                redo: .page_cleared(
                    page
                )
            )

        default:
            return nil
        }
    }
}

private extension DrawingDocumentState {
    func page(
        id: DrawingPageIdentifier
    ) -> DrawingPage? {
        document.pages.first { page in
            page.id == id
        }
    }

    func finishedStroke(
        id: DrawingStrokeIdentifier
    ) -> DrawingStroke? {
        for page in document.pages {
            if let stroke = page.strokes.first(where: { $0.id == id }) {
                return stroke
            }
        }

        return nil
    }
}

public final class DrawingPadNetworkSession: @unchecked Sendable {
    public let page: DrawingPageIdentifier
    public let pageSize: DrawingSize
    public let tool: DrawingTool
    public let client: DrawingNetworkPadClient
    public let runtime: DrawingPadAppRuntime
    public let states: AsyncStream<DrawingDocumentState>

    private let broadcaster: DrawingPadStateBroadcaster
    private let mirror: DrawingPadNetworkDocumentMirror

    public init(
        host: String,
        port: UInt16 = 47_777,
        page: DrawingPageIdentifier,
        pageSize: DrawingSize,
        tool: DrawingTool,
        maximumPointCount: Int = 8
    ) throws {
        self.page = page
        self.pageSize = pageSize
        self.tool = tool

        let client = try DrawingNetworkPadClient(
            host: host,
            port: port
        )
        let broadcaster = DrawingPadStateBroadcaster()
        let mirror = try DrawingPadNetworkDocumentMirror(
            page: page,
            pageSize: pageSize,
            broadcaster: broadcaster
        )

        self.client = client
        self.broadcaster = broadcaster
        self.mirror = mirror
        self.states = broadcaster.stream

        self.runtime = try DrawingPadAppRuntime(
            page: page,
            tool: tool,
            maximumPointCount: maximumPointCount
        ) { [client, mirror] message in
            try await mirror.applyUser(
                message
            )

            try await client.send(
                message
            )
        }
    }

    public func start() {
        client.start()
    }

    public func close() {
        client.close()
        broadcaster.finish()
    }

    public func connect() async throws {
        try await client.connect()
    }

    public func snapshot() async -> DrawingDocumentState {
        await mirror.snapshot()
    }

    public func clear() async throws {
        let event = DrawingEvent.page_cleared(
            page
        )

        try await mirror.applyUser(
            event
        )

        try await client.send(
            .event(
                event
            )
        )
    }

    public func undo() async throws {
        guard let event = try await mirror.makeUndoEvent() else {
            return
        }

        try await client.send(
            .event(
                event
            )
        )
    }

    public func redo() async throws {
        guard let event = try await mirror.makeRedoEvent() else {
            return
        }

        try await client.send(
            .event(
                event
            )
        )
    }
}
