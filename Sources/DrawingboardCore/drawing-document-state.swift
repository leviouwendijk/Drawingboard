import Foundation

public struct DrawingDocumentState: Sendable, Hashable {
    public var document: DrawingDocument
    public var openStrokes: [DrawingStrokeIdentifier: DrawingStroke]

    public init(
        document: DrawingDocument,
        openStrokes: [DrawingStrokeIdentifier: DrawingStroke] = [:]
    ) {
        self.document = document
        self.openStrokes = openStrokes
    }
}

public struct DrawingDocumentReducer: Sendable {
    public init() {}

    public func apply(
        _ event: DrawingEvent,
        to state: inout DrawingDocumentState
    ) throws {
        switch event {
        case .page_created(let page):
            try create(
                page,
                in: &state
            )

        case .page_selected(let id):
            try select(
                page: id,
                in: &state
            )

        case .page_cleared(let id):
            try clear(
                page: id,
                in: &state
            )

        case .stroke_began(let stroke):
            try begin(
                stroke,
                in: &state
            )

        case .stroke_moved(let move):
            try applyMove(
                move,
                in: &state
            )

        case .stroke_ended(let end):
            try applyEnd(
                end,
                in: &state
            )

        case .stroke_cancelled(let id):
            try cancel(
                stroke: id,
                in: &state
            )
        }
    }
}

private extension DrawingDocumentReducer {
    func create(
        _ page: DrawingPage,
        in state: inout DrawingDocumentState
    ) throws {
        guard !state.document.pages.contains(where: { $0.id == page.id }) else {
            throw DrawingError.duplicatePage(
                page.id.rawValue
            )
        }

        state.document.pages.append(
            page
        )
    }

    func select(
        page id: DrawingPageIdentifier,
        in state: inout DrawingDocumentState
    ) throws {
        guard state.document.pages.contains(where: { $0.id == id }) else {
            throw DrawingError.missingPage(
                id.rawValue
            )
        }

        state.document.activePage = id
    }

    func clear(
        page id: DrawingPageIdentifier,
        in state: inout DrawingDocumentState
    ) throws {
        guard let index = state.document.pages.firstIndex(where: { $0.id == id }) else {
            throw DrawingError.missingPage(
                id.rawValue
            )
        }

        state.document.pages[index].strokes.removeAll()

        state.openStrokes = state.openStrokes.filter { _, stroke in
            stroke.page != id
        }
    }

    func begin(
        _ stroke: DrawingStroke,
        in state: inout DrawingDocumentState
    ) throws {
        guard state.document.pages.contains(where: { $0.id == stroke.page }) else {
            throw DrawingError.missingPage(
                stroke.page.rawValue
            )
        }

        guard state.openStrokes[stroke.id] == nil else {
            throw DrawingError.duplicateOpenStroke(
                stroke.id.rawValue
            )
        }

        state.openStrokes[stroke.id] = stroke
    }

    func applyMove(
        _ move: DrawingStrokeMove,
        in state: inout DrawingDocumentState
    ) throws {
        guard var stroke = state.openStrokes[move.stroke] else {
            throw DrawingError.missingOpenStroke(
                move.stroke.rawValue
            )
        }

        try stroke.append(
            points: move.points
        )

        state.openStrokes[move.stroke] = stroke
    }

    func applyEnd(
        _ end: DrawingStrokeEnd,
        in state: inout DrawingDocumentState
    ) throws {
        guard var stroke = state.openStrokes[end.stroke] else {
            throw DrawingError.missingOpenStroke(
                end.stroke.rawValue
            )
        }

        if !end.points.isEmpty {
            try stroke.append(
                points: end.points
            )
        }

        guard let pageIndex = state.document.pages.firstIndex(where: { $0.id == stroke.page }) else {
            throw DrawingError.missingPage(
                stroke.page.rawValue
            )
        }

        state.document.pages[pageIndex].strokes.append(
            stroke
        )
        state.openStrokes.removeValue(
            forKey: end.stroke
        )
    }

    func cancel(
        stroke id: DrawingStrokeIdentifier,
        in state: inout DrawingDocumentState
    ) throws {
        guard state.openStrokes.removeValue(forKey: id) != nil else {
            throw DrawingError.missingOpenStroke(
                id.rawValue
            )
        }
    }
}
