#if os(iOS)

import DrawingboardCore
import DrawingboardPadRuntime
import Foundation
import SwiftUI
import UIKit

public struct DrawingPadCanvasCommand: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case zoomIn
        case zoomOut
        case fitPage
    }

    public let id: UUID
    public let kind: Kind

    public init(
        kind: Kind,
        id: UUID = UUID()
    ) {
        self.id = id
        self.kind = kind
    }

    public static func zoomIn() -> DrawingPadCanvasCommand {
        DrawingPadCanvasCommand(
            kind: .zoomIn
        )
    }

    public static func zoomOut() -> DrawingPadCanvasCommand {
        DrawingPadCanvasCommand(
            kind: .zoomOut
        )
    }

    public static func fitPage() -> DrawingPadCanvasCommand {
        DrawingPadCanvasCommand(
            kind: .fitPage
        )
    }
}

public struct DrawingPadCanvas: UIViewRepresentable {
    public final class Coordinator {
        var lastCommandID: UUID?
    }

    public let runtime: DrawingPadAppRuntime
    public let configuration: DrawingPadCanvasConfiguration
    public let state: DrawingDocumentState?
    public let tool: DrawingTool
    public let command: DrawingPadCanvasCommand?
    public let onError: (Error) -> Void

    public init(
        runtime: DrawingPadAppRuntime,
        configuration: DrawingPadCanvasConfiguration,
        state: DrawingDocumentState? = nil,
        tool: DrawingTool,
        command: DrawingPadCanvasCommand? = nil,
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        self.runtime = runtime
        self.configuration = configuration
        self.state = state
        self.tool = tool
        self.command = command
        self.onError = onError
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(
        context: Context
    ) -> DrawingPadCanvasView {
        DrawingPadCanvasView(
            runtime: runtime,
            configuration: configuration,
            tool: tool,
            onError: onError
        )
    }

    public func updateUIView(
        _ uiView: DrawingPadCanvasView,
        context: Context
    ) {
        uiView.update(
            state: state,
            tool: tool
        )

        if let command,
           context.coordinator.lastCommandID != command.id {
            context.coordinator.lastCommandID = command.id

            uiView.apply(
                command: command
            )
        }
    }
}

#endif
