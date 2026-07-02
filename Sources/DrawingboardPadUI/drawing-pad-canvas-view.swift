#if os(iOS)

import DrawingboardCore
import DrawingboardPadRuntime
import DrawingboardRendering
import DrawingboardProtocol
import Foundation
import UIKit

public struct DrawingPadCanvasConfiguration: Sendable, Hashable {
    public let pageSize: DrawingSize
    public let margin: Double
    public let allowsFingerDrawing: Bool

    public init(
        pageSize: DrawingSize,
        margin: Double = 0,
        allowsFingerDrawing: Bool = false
    ) {
        self.pageSize = pageSize
        self.margin = margin
        self.allowsFingerDrawing = allowsFingerDrawing
    }
}

@MainActor
public final class DrawingPadCanvasView: UIView {
    private let runtime: DrawingPadAppRuntime
    private let configuration: DrawingPadCanvasConfiguration
    private let onError: (Error) -> Void

    private var state: DrawingDocumentState?
    private weak var activeTouch: UITouch?
    private var pendingOperation: Task<Void, Never>?

    public init(
        runtime: DrawingPadAppRuntime,
        configuration: DrawingPadCanvasConfiguration,
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        self.runtime = runtime
        self.configuration = configuration
        self.onError = onError

        super.init(
            frame: .zero
        )

        isMultipleTouchEnabled = false
        backgroundColor = .white
        contentMode = .redraw
    }

    public required init?(
        coder: NSCoder
    ) {
        nil
    }

    public func update(
        state: DrawingDocumentState?
    ) {
        self.state = state
        setNeedsDisplay()
    }

    public override func draw(
        _ rect: CGRect
    ) {
        super.draw(
            rect
        )

        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        UIColor.white.setFill()
        context.fill(
            bounds
        )

        do {
            let viewport = try currentViewport()
            let origin = viewport.pageToView(
                DrawingCoordinate(
                    x: 0,
                    y: 0
                )
            )
            let farCorner = viewport.pageToView(
                DrawingCoordinate(
                    x: configuration.pageSize.width,
                    y: configuration.pageSize.height
                )
            )

            let pageRect = CGRect(
                x: origin.x,
                y: origin.y,
                width: farCorner.x - origin.x,
                height: farCorner.y - origin.y
            )

            UIColor(
                white: 0.96,
                alpha: 1
            ).setFill()
            context.fill(
                pageRect
            )

            UIColor(
                white: 0.82,
                alpha: 1
            ).setStroke()
            context.stroke(
                pageRect,
                width: 1
            )

            try drawCommands(
                context: context,
                viewport: viewport
            )
        } catch {
            onError(
                error
            )
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    public override func touchesBegan(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        guard activeTouch == nil,
              let touch = acceptedTouch(
                from: touches
              ) else {
            return
        }

        activeTouch = touch

        do {
            let point = try drawingPoint(
                from: touch,
                predicted: false
            )

            perform {
                try await self.runtime.begin(
                    at: point
                )
            }
        } catch {
            onError(
                error
            )
        }
    }

    public override func touchesMoved(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        guard let activeTouch,
              touches.contains(
                activeTouch
              ) else {
            return
        }

        do {
            let sourceTouches = event?.coalescedTouches(
                for: activeTouch
            ) ?? [
                activeTouch,
            ]

            let points = try sourceTouches.map { touch in
                try drawingPoint(
                    from: touch,
                    predicted: false
                )
            }

            perform {
                try await self.runtime.append(
                    points: points
                )
            }
        } catch {
            onError(
                error
            )
        }
    }

    public override func touchesEnded(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        guard let activeTouch,
              touches.contains(
                activeTouch
              ) else {
            return
        }

        do {
            let sourceTouches = event?.coalescedTouches(
                for: activeTouch
            ) ?? [
                activeTouch,
            ]

            let points = try sourceTouches.map { touch in
                try drawingPoint(
                    from: touch,
                    predicted: false
                )
            }

            self.activeTouch = nil

            perform {
                try await self.runtime.end(
                    points: points
                )
            }
        } catch {
            self.activeTouch = nil
            onError(
                error
            )
        }
    }

    public override func touchesCancelled(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        guard let activeTouch,
              touches.contains(
                activeTouch
              ) else {
            return
        }

        self.activeTouch = nil

        perform {
            try await self.runtime.cancel()
        }
    }
}

private extension DrawingPadCanvasView {
    func drawCommands(
        context: CGContext,
        viewport: DrawingViewport
    ) throws {
        guard let state else {
            return
        }

        let frame = try DrawingRenderCommandResolver().resolve(
            state: state,
            viewport: viewport
        )

        for command in frame.commands {
            switch command {
            case .stroke(let stroke):
                drawStroke(
                    stroke,
                    context: context
                )
            }
        }
    }

    func drawStroke(
        _ stroke: DrawingRenderStrokeCommand,
        context: CGContext
    ) {
        guard let first = stroke.points.first else {
            return
        }

        context.saveGState()
        context.beginPath()
        context.move(
            to: CGPoint(
                x: first.x,
                y: first.y
            )
        )

        for point in stroke.points.dropFirst() {
            context.addLine(
                to: CGPoint(
                    x: point.x,
                    y: point.y
                )
            )
        }

        context.setLineWidth(
            stroke.width
        )
        context.setLineCap(
            .round
        )
        context.setLineJoin(
            .round
        )
        context.setStrokeColor(
            UIColor(
                red: stroke.color.r,
                green: stroke.color.g,
                blue: stroke.color.b,
                alpha: stroke.color.a
            ).cgColor
        )
        context.strokePath()
        context.restoreGState()
    }
    func acceptedTouch(
        from touches: Set<UITouch>
    ) -> UITouch? {
        touches.first { touch in
            if touch.type == .pencil {
                return true
            }

            return configuration.allowsFingerDrawing &&
                touch.type == .direct
        }
    }

    func drawingPoint(
        from touch: UITouch,
        predicted: Bool
    ) throws -> DrawingPoint {
        let location = touch.location(
            in: self
        )
        let viewport = try currentViewport()
        let pageCoordinate = viewport.viewToPage(
            DrawingCoordinate(
                x: location.x,
                y: location.y
            )
        )

        return DrawingPoint(
            x: pageCoordinate.x,
            y: pageCoordinate.y,
            time: touch.timestamp,
            force: touch.force,
            altitude: touch.altitudeAngle,
            azimuth: touch.azimuthAngle(
                in: self
            ),
            predicted: predicted
        )
    }

    func currentViewport() throws -> DrawingViewport {
        let viewSize = try DrawingSize(
            width: max(
                Double(bounds.width),
                1
            ),
            height: max(
                Double(bounds.height),
                1
            )
        )

        return try DrawingViewport.fitPage(
            pageSize: configuration.pageSize,
            viewSize: viewSize,
            margin: configuration.margin
        )
    }

    func perform(
        _ operation: @escaping @MainActor () async throws -> Void
    ) {
        let previousOperation = pendingOperation

        let nextOperation = Task { @MainActor in
            await previousOperation?.value

            do {
                try await operation()
            } catch {
                onError(
                    error
                )
            }
        }

        pendingOperation = nextOperation
    }
}

#endif
