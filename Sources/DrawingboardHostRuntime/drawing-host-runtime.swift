import DrawingboardCore
import DrawingboardProtocol
import Foundation

public actor DrawingHostRuntime {
    private var state: DrawingDocumentState
    private var log: DrawingEventLog
    private let reducer: DrawingDocumentReducer

    public init(
        document: DrawingDocument,
        reducer: DrawingDocumentReducer = DrawingDocumentReducer()
    ) {
        self.state = DrawingDocumentState(
            document: document
        )
        self.log = DrawingEventLog()
        self.reducer = reducer
    }

    @discardableResult
    public func apply(
        _ message: DrawingMessage
    ) throws -> DrawingEventRecord? {
        try apply(
            message,
            time: Date().timeIntervalSince1970
        )
    }

    @discardableResult
    public func apply(
        _ message: DrawingMessage,
        time: TimeInterval
    ) throws -> DrawingEventRecord? {
        switch message {
        case .event(let event):
            try reducer.apply(
                event,
                to: &state
            )

            return try log.append(
                event,
                time: time
            )

        case .snapshot(let document):
            state = DrawingDocumentState(
                document: document
            )
            log = DrawingEventLog()

            return nil

        case .hello,
             .session_accepted:
            return nil
        }
    }

    public func snapshot() -> DrawingDocumentState {
        state
    }

    public func eventLog() -> DrawingEventLog {
        log
    }
}
