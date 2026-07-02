#if os(iOS)

import DrawingboardPadRuntime
import Foundation
import SwiftUI
import UIKit

public struct DrawingPadCanvas: UIViewRepresentable {
    public let runtime: DrawingPadAppRuntime
    public let configuration: DrawingPadCanvasConfiguration
    public let onError: (Error) -> Void

    public init(
        runtime: DrawingPadAppRuntime,
        configuration: DrawingPadCanvasConfiguration,
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        self.runtime = runtime
        self.configuration = configuration
        self.onError = onError
    }

    public func makeUIView(
        context: Context
    ) -> DrawingPadCanvasView {
        DrawingPadCanvasView(
            runtime: runtime,
            configuration: configuration,
            onError: onError
        )
    }

    public func updateUIView(
        _ uiView: DrawingPadCanvasView,
        context: Context
    ) {}
}

#endif
