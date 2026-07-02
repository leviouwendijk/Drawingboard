#if os(iOS)

import DrawingboardCore
import DrawingboardPadRuntime
import DrawingboardProtocol
import DrawingboardRendering
import Foundation
import UIKit

public enum DrawingPadTouchInputPolicy: String, Sendable, Codable, Hashable, CaseIterable {
    case pencilOnly
    case fingerOnly
    case pencilAndFinger
}

public struct DrawingPadCanvasConfiguration: Sendable, Hashable {
    public let pageSize: DrawingSize
    public let margin: Double
    public let inputPolicy: DrawingPadTouchInputPolicy

    public init(
        pageSize: DrawingSize,
        margin: Double = 0,
        inputPolicy: DrawingPadTouchInputPolicy = .pencilOnly
    ) {
        self.pageSize = pageSize
        self.margin = margin
        self.inputPolicy = inputPolicy
    }

    public init(
        pageSize: DrawingSize,
        margin: Double = 0,
        allowsFingerDrawing: Bool
    ) {
        self.init(
            pageSize: pageSize,
            margin: margin,
            inputPolicy: allowsFingerDrawing ? .pencilAndFinger : .pencilOnly
        )
    }

    public var allowsFingerDrawing: Bool {
        switch inputPolicy {
        case .pencilOnly:
            false

        case .fingerOnly,
             .pencilAndFinger:
            true
        }
    }
}

@MainActor
public final class DrawingPadCanvasView: UIView, UIGestureRecognizerDelegate {
    private let runtime: DrawingPadAppRuntime
    private let configuration: DrawingPadCanvasConfiguration
    private let onError: (Error) -> Void

    private var state: DrawingDocumentState?
    private var viewport: DrawingViewport?
    private var pinchBaseViewport: DrawingViewport?
    private var panBaseViewport: DrawingViewport?

    private weak var activeTouch: UITouch?
    private var pendingOperation: Task<Void, Never>?

    private var tool: DrawingTool
    private var erasedStrokeIDsDuringActiveTouch: Set<DrawingStrokeIdentifier> = []
    private var isPinching = false

    public init(
        runtime: DrawingPadAppRuntime,
        configuration: DrawingPadCanvasConfiguration,
        tool: DrawingTool,
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        self.runtime = runtime
        self.configuration = configuration
        self.tool = tool
        self.onError = onError

        super.init(
            frame: .zero
        )

        isMultipleTouchEnabled = true
        backgroundColor = .white
        contentMode = .redraw

        installGestureRecognizers()
    }

    public required init?(
        coder: NSCoder
    ) {
        nil
    }

    public func update(
        state: DrawingDocumentState?,
        tool: DrawingTool
    ) {
        self.state = state
        self.tool = tool

        setNeedsDisplay()
    }

    public func apply(
        command: DrawingPadCanvasCommand
    ) {
        do {
            switch command.kind {
            case .zoomIn:
                try zoom(
                    by: 1.25
                )

            case .zoomOut:
                try zoom(
                    by: 0.8
                )

            case .fitPage:
                viewport = try fittedViewport()
                setNeedsDisplay()
            }
        } catch {
            onError(
                error
            )
        }
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
            let pageRect = pageRect(
                viewport: viewport
            )

            UIColor(
                white: 0.96,
                alpha: 1
            ).setFill()
            context.fill(
                pageRect
            )

            context.saveGState()
            context.clip(
                to: pageRect
            )

            try drawCommands(
                context: context,
                viewport: viewport
            )

            context.restoreGState()

            UIColor(
                white: 0.82,
                alpha: 1
            ).setStroke()
            context.stroke(
                pageRect,
                width: 1
            )
        } catch {
            onError(
                error
            )
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        do {
            _ = try currentViewport()

            setNeedsDisplay()
        } catch {
            onError(
                error
            )
        }
    }

    public override func touchesBegan(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        if isMultiTouch(
            event: event,
            fallbackTouches: touches
        ) {
            cancelActiveStroke()
            return
        }

        guard activeTouch == nil,
              let touch = acceptedDrawingTouch(
                from: touches
              ) else {
            return
        }

        do {
            guard let point = try drawingPoint(
                from: touch,
                predicted: false
            ) else {
                return
            }

            activeTouch = touch

            if tool.kind == .eraser {
                erasedStrokeIDsDuringActiveTouch.removeAll()

                try erase(
                    at: point
                )

                return
            }

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

        if isMultiTouch(
            event: event,
            fallbackTouches: touches
        ) {
            cancelActiveStroke()
            return
        }

        do {
            let sourceTouches = event?.coalescedTouches(
                for: activeTouch
            ) ?? [
                activeTouch,
            ]

            let points = try sourceTouches.compactMap { touch in
                try drawingPoint(
                    from: touch,
                    predicted: false
                )
            }

            guard !points.isEmpty else {
                return
            }

            if tool.kind == .eraser {
                for point in points {
                    try erase(
                        at: point
                    )
                }

                return
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

        if tool.kind == .eraser {
            erasedStrokeIDsDuringActiveTouch.removeAll()
            self.activeTouch = nil
            return
        }

        do {
            let sourceTouches = event?.coalescedTouches(
                for: activeTouch
            ) ?? [
                activeTouch,
            ]

            let points = try sourceTouches.compactMap { touch in
                try drawingPoint(
                    from: touch,
                    predicted: false
                )
            }

            erasedStrokeIDsDuringActiveTouch.removeAll()
            self.activeTouch = nil

            perform {
                try await self.runtime.end(
                    points: points
                )
            }
        } catch {
            erasedStrokeIDsDuringActiveTouch.removeAll()
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

        erasedStrokeIDsDuringActiveTouch.removeAll()
        self.activeTouch = nil

        if tool.kind == .eraser {
            return
        }

        perform {
            try await self.runtime.cancel()
        }
    }

    public func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer is UIPinchGestureRecognizer {
            return true
        }

        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            return pan.numberOfTouches >= minimumNavigationTouchCount()
        }

        return true
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        let firstIsPinch = gestureRecognizer is UIPinchGestureRecognizer
        let secondIsPinch = otherGestureRecognizer is UIPinchGestureRecognizer
        let firstIsPan = gestureRecognizer is UIPanGestureRecognizer
        let secondIsPan = otherGestureRecognizer is UIPanGestureRecognizer

        return firstIsPinch && secondIsPan ||
            firstIsPan && secondIsPinch
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        touch.type == .direct
    }
}

private extension DrawingPadCanvasView {
    func installGestureRecognizers() {
        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(handlePinch)
        )
        pinch.delegate = self
        pinch.cancelsTouchesInView = false

        addGestureRecognizer(
            pinch
        )

        let pan = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePan)
        )
        pan.delegate = self
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 2
        pan.cancelsTouchesInView = false

        addGestureRecognizer(
            pan
        )
    }

    @objc
    func handlePinch(
        _ recognizer: UIPinchGestureRecognizer
    ) {
        do {
            switch recognizer.state {
            case .began:
                isPinching = true
                panBaseViewport = nil
                cancelActiveStroke()

                pinchBaseViewport = try currentViewport()

            case .changed:
                isPinching = true

                let base = try pinchBaseViewport ?? currentViewport()
                let location = recognizer.location(
                    in: self
                )

                viewport = try zoomedViewport(
                    base: base,
                    requestedScale: base.scale * Double(
                        recognizer.scale
                    ),
                    anchor: DrawingCoordinate(
                        x: Double(location.x),
                        y: Double(location.y)
                    )
                )

                setNeedsDisplay()

            case .ended,
                 .cancelled,
                 .failed:
                isPinching = false
                pinchBaseViewport = nil

            default:
                break
            }
        } catch {
            onError(
                error
            )
        }
    }

    @objc
    func handlePan(
        _ recognizer: UIPanGestureRecognizer
    ) {
        do {
            guard !isPinching else {
                return
            }

            guard recognizer.numberOfTouches >= minimumNavigationTouchCount() else {
                return
            }

            switch recognizer.state {
            case .began:
                cancelActiveStroke()

                panBaseViewport = try currentViewport()

            case .changed:
                let base = try panBaseViewport ?? currentViewport()
                let translation = recognizer.translation(
                    in: self
                )

                viewport = try base.panned(
                    by: DrawingVector(
                        dx: Double(translation.x),
                        dy: Double(translation.y)
                    )
                )

                setNeedsDisplay()

            case .ended,
                 .cancelled,
                 .failed:
                panBaseViewport = nil

            default:
                break
            }
        } catch {
            onError(
                error
            )
        }
    }

    func minimumNavigationTouchCount() -> Int {
        switch configuration.inputPolicy {
        case .pencilOnly:
            1

        case .fingerOnly,
             .pencilAndFinger:
            2
        }
    }

    func acceptsDrawingTouch(
        _ touch: UITouch
    ) -> Bool {
        switch touch.type {
        case .pencil:
            switch configuration.inputPolicy {
            case .pencilOnly,
                 .pencilAndFinger:
                return true

            case .fingerOnly:
                return false
            }

        case .direct:
            switch configuration.inputPolicy {
            case .fingerOnly,
                 .pencilAndFinger:
                return true

            case .pencilOnly:
                return false
            }

        default:
            return false
        }
    }

    func acceptedDrawingTouch(
        from touches: Set<UITouch>
    ) -> UITouch? {
        touches.first { touch in
            acceptsDrawingTouch(
                touch
            )
        }
    }

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
                x: CGFloat(first.x),
                y: CGFloat(first.y)
            )
        )

        for point in stroke.points.dropFirst() {
            context.addLine(
                to: CGPoint(
                    x: CGFloat(point.x),
                    y: CGFloat(point.y)
                )
            )
        }

        context.setLineWidth(
            CGFloat(stroke.width)
        )
        context.setLineCap(
            .round
        )
        context.setLineJoin(
            .round
        )
        context.setStrokeColor(
            UIColor(
                red: CGFloat(stroke.color.r),
                green: CGFloat(stroke.color.g),
                blue: CGFloat(stroke.color.b),
                alpha: CGFloat(stroke.color.a)
            ).cgColor
        )
        context.strokePath()
        context.restoreGState()
    }

    func drawingPoint(
        from touch: UITouch,
        predicted: Bool
    ) throws -> DrawingPoint? {
        let location = touch.location(
            in: self
        )
        let viewport = try currentViewport()
        let pageCoordinate = viewport.viewToPage(
            DrawingCoordinate(
                x: Double(location.x),
                y: Double(location.y)
            )
        )

        guard isInsidePage(
            pageCoordinate
        ) else {
            return nil
        }

        return DrawingPoint(
            x: pageCoordinate.x,
            y: pageCoordinate.y,
            time: touch.timestamp,
            force: normalizedForce(
                from: touch
            ),
            altitude: touch.altitudeAngle,
            azimuth: touch.azimuthAngle(
                in: self
            ),
            predicted: predicted
        )
    }

    func normalizedForce(
        from touch: UITouch
    ) -> Double? {
        guard touch.maximumPossibleForce > 0 else {
            return nil
        }

        let normalized = touch.force / touch.maximumPossibleForce

        return min(
            max(
                Double(normalized),
                0
            ),
            1
        )
    }

    func isInsidePage(
        _ coordinate: DrawingCoordinate
    ) -> Bool {
        coordinate.x >= 0 &&
        coordinate.y >= 0 &&
        coordinate.x <= configuration.pageSize.width &&
        coordinate.y <= configuration.pageSize.height
    }

    func pageRect(
        viewport: DrawingViewport
    ) -> CGRect {
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

        return CGRect(
            x: CGFloat(origin.x),
            y: CGFloat(origin.y),
            width: CGFloat(farCorner.x - origin.x),
            height: CGFloat(farCorner.y - origin.y)
        )
    }

    func currentViewport() throws -> DrawingViewport {
        let viewSize = try currentViewSize()

        if let viewport,
           viewport.viewSize == viewSize {
            return viewport
        }

        let fitted = try DrawingViewport.fitPage(
            pageSize: configuration.pageSize,
            viewSize: viewSize,
            margin: configuration.margin
        )

        viewport = fitted

        return fitted
    }

    func fittedViewport() throws -> DrawingViewport {
        try DrawingViewport.fitPage(
            pageSize: configuration.pageSize,
            viewSize: try currentViewSize(),
            margin: configuration.margin
        )
    }

    func currentViewSize() throws -> DrawingSize {
        try DrawingSize(
            width: max(
                Double(bounds.width),
                1
            ),
            height: max(
                Double(bounds.height),
                1
            )
        )
    }

    func zoom(
        by factor: Double
    ) throws {
        let base = try currentViewport()
        let center = DrawingCoordinate(
            x: Double(bounds.midX),
            y: Double(bounds.midY)
        )
        let requestedScale = base.scale * factor

        viewport = try zoomedViewport(
            base: base,
            requestedScale: requestedScale,
            anchor: center
        )

        setNeedsDisplay()
    }

    func zoomedViewport(
        base: DrawingViewport,
        requestedScale: Double,
        anchor: DrawingCoordinate
    ) throws -> DrawingViewport {
        let fitted = try fittedViewport()
        let minimumScale = fitted.scale * 0.5
        let maximumScale = fitted.scale * 8

        let clampedScale = min(
            max(
                requestedScale,
                minimumScale
            ),
            maximumScale
        )

        let factor = clampedScale / base.scale

        return try base.zoomed(
            by: factor,
            around: anchor
        )
    }

    func isMultiTouch(
        event: UIEvent?,
        fallbackTouches: Set<UITouch>
    ) -> Bool {
        let activeTouchCount = event?.allTouches?.filter { touch in
            touch.phase != .ended &&
            touch.phase != .cancelled
        }.count ?? fallbackTouches.count

        return activeTouchCount > 1
    }

    func cancelActiveStroke() {
        guard activeTouch != nil else {
            return
        }

        let wasErasing = tool.kind == .eraser

        activeTouch = nil
        erasedStrokeIDsDuringActiveTouch.removeAll()

        guard !wasErasing else {
            return
        }

        perform {
            try await self.runtime.cancel()
        }
    }

    func erase(
        at point: DrawingPoint
    ) throws {
        guard let stroke = try nearestFinishedStroke(
            to: point
        ) else {
            return
        }

        guard !erasedStrokeIDsDuringActiveTouch.contains(
            stroke
        ) else {
            return
        }

        erasedStrokeIDsDuringActiveTouch.insert(
            stroke
        )

        perform {
            try await self.runtime.remove(
                stroke: stroke
            )
        }
    }

    func nearestFinishedStroke(
        to point: DrawingPoint
    ) throws -> DrawingStrokeIdentifier? {
        guard let state,
              let page = state.document.pages.first(where: { page in
                  page.id == state.document.activePage
              }) else {
            return nil
        }

        let viewport = try currentViewport()
        let threshold = max(
            tool.width * 1.75,
            18 / viewport.scale
        )

        var bestStroke: DrawingStrokeIdentifier?
        var bestDistance = Double.greatestFiniteMagnitude

        for stroke in page.strokes {
            let distance = distance(
                from: point,
                to: stroke
            )

            if distance < bestDistance {
                bestDistance = distance
                bestStroke = stroke.id
            }
        }

        guard bestDistance <= threshold else {
            return nil
        }

        return bestStroke
    }

    func distance(
        from point: DrawingPoint,
        to stroke: DrawingStroke
    ) -> Double {
        guard let first = stroke.points.first else {
            return Double.greatestFiniteMagnitude
        }

        guard stroke.points.count > 1 else {
            return distance(
                from: point,
                to: first
            )
        }

        var best = Double.greatestFiniteMagnitude

        for index in 1..<stroke.points.count {
            best = min(
                best,
                distance(
                    from: point,
                    toSegmentStart: stroke.points[index - 1],
                    end: stroke.points[index]
                )
            )
        }

        return best
    }

    func distance(
        from point: DrawingPoint,
        to other: DrawingPoint
    ) -> Double {
        hypot(
            point.x - other.x,
            point.y - other.y
        )
    }

    func distance(
        from point: DrawingPoint,
        toSegmentStart start: DrawingPoint,
        end: DrawingPoint
    ) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y

        let lengthSquared = dx * dx + dy * dy

        guard lengthSquared > 0 else {
            return distance(
                from: point,
                to: start
            )
        }

        let rawT = (
            (point.x - start.x) * dx +
            (point.y - start.y) * dy
        ) / lengthSquared

        let t = min(
            max(
                rawT,
                0
            ),
            1
        )

        let projectionX = start.x + t * dx
        let projectionY = start.y + t * dy

        return hypot(
            point.x - projectionX,
            point.y - projectionY
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
