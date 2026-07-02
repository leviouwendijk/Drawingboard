import DrawingboardCore
import DrawingboardNetworkTransport
import DrawingboardPadRuntime
import DrawingboardProtocol
import Foundation

public enum DrawingPadSceneError: Error, Sendable, LocalizedError, Equatable {
    case missingScene(String)
    case cannotDeleteOnlyScene
    case noPreviousScene
    case noNextScene

    public var errorDescription: String? {
        switch self {
        case .missingScene(let id):
            "Missing scene: \(id)."

        case .cannotDeleteOnlyScene:
            "Cannot delete the final remaining scene."

        case .noPreviousScene:
            "There is no previous scene."

        case .noNextScene:
            "There is no next scene."
        }
    }
}

public struct DrawingPadSceneInfo: Sendable, Hashable {
    public let pages: [DrawingPageIdentifier]
    public let activePage: DrawingPageIdentifier

    public init(
        pages: [DrawingPageIdentifier],
        activePage: DrawingPageIdentifier
    ) {
        self.pages = pages
        self.activePage = activePage
    }

    public var activeIndex: Int {
        pages.firstIndex(
            of: activePage
        ) ?? 0
    }

    public var count: Int {
        pages.count
    }

    public var previousPage: DrawingPageIdentifier? {
        guard activeIndex > 0 else {
            return nil
        }

        return pages[
            activeIndex - 1
        ]
    }

    public var nextPage: DrawingPageIdentifier? {
        guard activeIndex + 1 < pages.count else {
            return nil
        }

        return pages[
            activeIndex + 1
        ]
    }
}

private struct DrawingPadHistoryEntry: Sendable {
    let page: DrawingPageIdentifier
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

    private var undoStacks: [DrawingPageIdentifier: [DrawingPadHistoryEntry]]
    private var redoStacks: [DrawingPageIdentifier: [DrawingPadHistoryEntry]]

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
        self.undoStacks = [:]
        self.redoStacks = [:]

        broadcaster.yield(
            state
        )
    }

    func snapshot() -> DrawingDocumentState {
        state
    }

    func sceneInfo() -> DrawingPadSceneInfo {
        DrawingPadSceneInfo(
            pages: state.document.pages.map(\.id),
            activePage: state.document.activePage
        )
    }

    func contains(
        page id: DrawingPageIdentifier
    ) -> Bool {
        state.document.pages.contains { page in
            page.id == id
        }
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
            undoStacks.removeAll()
            redoStacks.removeAll()
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

        if case .page_deleted(let page) = event {
            undoStacks.removeValue(
                forKey: page
            )
            redoStacks.removeValue(
                forKey: page
            )
        }

        if let history = historyEntry(
            for: event,
            previousState: previousState,
            currentState: state
        ) {
            appendHistory(
                history
            )
        }

        publish()
    }

    func makeUndoMessage(
        for page: DrawingPageIdentifier? = nil
    ) throws -> DrawingMessage? {
        let targetPage = page ?? state.document.activePage

        guard var stack = undoStacks[targetPage],
              let entry = stack.popLast() else {
            return nil
        }

        undoStacks[targetPage] = stack

        try reducer.apply(
            entry.undo,
            to: &state
        )

        redoStacks[targetPage, default: []].append(
            entry
        )

        publish()

        return .snapshot(
            state.document
        )
    }

    func makeRedoMessage(
        for page: DrawingPageIdentifier? = nil
    ) throws -> DrawingMessage? {
        let targetPage = page ?? state.document.activePage

        guard var stack = redoStacks[targetPage],
              let entry = stack.popLast() else {
            return nil
        }

        redoStacks[targetPage] = stack

        try reducer.apply(
            entry.redo,
            to: &state
        )

        undoStacks[targetPage, default: []].append(
            entry
        )

        publish()

        return .snapshot(
            state.document
        )
    }
}

private extension DrawingPadNetworkDocumentMirror {
    func publish() {
        broadcaster.yield(
            state
        )
    }

    func appendHistory(
        _ history: DrawingPadHistoryEntry
    ) {
        undoStacks[history.page, default: []].append(
            history
        )
        redoStacks[history.page] = []
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
                page: stroke.page,
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
                page: stroke.page,
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
                page: page,
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

        let snapshot = await mirror.snapshot()

        try await client.send(
            .snapshot(
                snapshot.document
            )
        )
    }

    public func snapshot() async -> DrawingDocumentState {
        await mirror.snapshot()
    }

    public func sceneInfo() async -> DrawingPadSceneInfo {
        await mirror.sceneInfo()
    }

    public func setTool(
        _ tool: DrawingTool
    ) async throws {
        try await runtime.setTool(
            tool
        )
    }

    public func createScene() async throws {
        let scene = DrawingPageIdentifier.next()
        let page = DrawingPage(
            id: scene,
            size: pageSize
        )

        try await runtime.setPage(
            scene
        )

        let createEvent = DrawingEvent.page_created(
            page
        )
        let selectEvent = DrawingEvent.page_selected(
            scene
        )

        try await mirror.applyUser(
            createEvent
        )
        try await mirror.applyUser(
            selectEvent
        )

        try await client.send(
            .event(
                createEvent
            )
        )
        try await client.send(
            .event(
                selectEvent
            )
        )
    }

    public func selectScene(
        _ page: DrawingPageIdentifier
    ) async throws {
        guard await mirror.contains(page: page) else {
            throw DrawingPadSceneError.missingScene(
                page.rawValue
            )
        }

        try await runtime.setPage(
            page
        )

        let event = DrawingEvent.page_selected(
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

    public func selectPreviousScene() async throws {
        let info = await mirror.sceneInfo()

        guard let previousPage = info.previousPage else {
            throw DrawingPadSceneError.noPreviousScene
        }

        try await selectScene(
            previousPage
        )
    }

    public func selectNextScene() async throws {
        let info = await mirror.sceneInfo()

        guard let nextPage = info.nextPage else {
            throw DrawingPadSceneError.noNextScene
        }

        try await selectScene(
            nextPage
        )
    }

    public func deleteScene(
        _ page: DrawingPageIdentifier
    ) async throws {
        let info = await mirror.sceneInfo()

        guard info.pages.contains(page) else {
            throw DrawingPadSceneError.missingScene(
                page.rawValue
            )
        }

        guard info.pages.count > 1 else {
            throw DrawingPadSceneError.cannotDeleteOnlyScene
        }

        if info.activePage == page,
           let replacementPage = replacementScene(
               deleting: page,
               in: info.pages
           ) {
            try await runtime.setPage(
                replacementPage
            )
        }

        let event = DrawingEvent.page_deleted(
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

    public func clear() async throws {
        let activePage = await mirror.sceneInfo().activePage
        let event = DrawingEvent.page_cleared(
            activePage
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
        guard let message = try await mirror.makeUndoMessage() else {
            return
        }

        try await client.send(
            message
        )
    }

    public func redo() async throws {
        guard let message = try await mirror.makeRedoMessage() else {
            return
        }

        try await client.send(
            message
        )
    }
}

private extension DrawingPadNetworkSession {
    func replacementScene(
        deleting page: DrawingPageIdentifier,
        in pages: [DrawingPageIdentifier]
    ) -> DrawingPageIdentifier? {
        guard let index = pages.firstIndex(
            of: page
        ) else {
            return nil
        }

        if index + 1 < pages.count {
            return pages[
                index + 1
            ]
        }

        if index > 0 {
            return pages[
                index - 1
            ]
        }

        return nil
    }
}
