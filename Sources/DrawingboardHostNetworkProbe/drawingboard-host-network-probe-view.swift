import AppKit
import DrawingboardCore
import DrawingboardRendering
import Foundation

@MainActor
final class DrawingboardHostNetworkProbeView: NSView {
    private var state: DrawingDocumentState
    private let pageSize: DrawingSize

    private var viewport: DrawingViewport?
    private var followsWindowFit = true

    private let controlsView = NSVisualEffectView()
    private let zoomOutButton = NSButton()
    private let fitButton = NSButton()
    private let zoomInButton = NSButton()

    init(
        frame frameRect: NSRect,
        state: DrawingDocumentState,
        pageSize: DrawingSize
    ) {
        self.state = state
        self.pageSize = pageSize

        super.init(
            frame: frameRect
        )

        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor

        installControls()
    }

    required init?(
        coder: NSCoder
    ) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    func update(
        state: DrawingDocumentState
    ) {
        self.state = state
        needsDisplay = true
    }

    override func layout() {
        super.layout()

        layoutControls()

        if followsWindowFit {
            viewport = nil
        } else {
            resizeViewportToCurrentBoundsIfNeeded()
        }

        needsDisplay = true
    }

    override func draw(
        _ dirtyRect: NSRect
    ) {
        super.draw(
            dirtyRect
        )

        NSColor.white.setFill()
        bounds.fill()

        do {
            let viewport = try currentViewport()
            let frame = try DrawingRenderCommandResolver().resolve(
                state: state,
                viewport: viewport
            )

            drawPageBackground(
                viewport: viewport
            )
            drawCommands(
                frame: frame
            )
        } catch {
            fputs(
                "DrawingboardHostNetworkProbeView draw failed: \(error.localizedDescription)\n",
                stderr
            )
        }
    }

    override func magnify(
        with event: NSEvent
    ) {
        do {
            let factor = max(
                0.1,
                1 + Double(event.magnification)
            )

            try zoom(
                by: factor,
                around: DrawingCoordinate(
                    x: Double(event.locationInWindow.x),
                    y: Double(bounds.height - event.locationInWindow.y)
                )
            )
        } catch {
            fputs(
                "DrawingboardHostNetworkProbeView magnify failed: \(error.localizedDescription)\n",
                stderr
            )
        }
    }

    override func scrollWheel(
        with event: NSEvent
    ) {
        do {
            if event.modifierFlags.contains(.option) {
                let delta = event.scrollingDeltaY
                let factor = delta > 0 ? 1.08 : 0.92

                try zoom(
                    by: factor,
                    around: DrawingCoordinate(
                        x: Double(bounds.midX),
                        y: Double(bounds.midY)
                    )
                )
            } else {
                try pan(
                    by: DrawingVector(
                        dx: Double(event.scrollingDeltaX),
                        dy: Double(event.scrollingDeltaY)
                    )
                )
            }
        } catch {
            fputs(
                "DrawingboardHostNetworkProbeView scroll failed: \(error.localizedDescription)\n",
                stderr
            )
        }
    }
}

private extension DrawingboardHostNetworkProbeView {
    func installControls() {
        controlsView.material = .hudWindow
        controlsView.blendingMode = .withinWindow
        controlsView.state = .active
        controlsView.wantsLayer = true
        controlsView.layer?.cornerRadius = 10
        controlsView.layer?.masksToBounds = true

        addSubview(
            controlsView
        )

        configureButton(
            zoomOutButton,
            symbolName: "minus.magnifyingglass",
            fallbackTitle: "−",
            action: #selector(zoomOutPressed)
        )

        configureButton(
            fitButton,
            symbolName: "rectangle.arrowtriangle.2.inward",
            fallbackTitle: "Fit",
            action: #selector(fitPressed)
        )

        configureButton(
            zoomInButton,
            symbolName: "plus.magnifyingglass",
            fallbackTitle: "+",
            action: #selector(zoomInPressed)
        )

        controlsView.addSubview(
            zoomOutButton
        )
        controlsView.addSubview(
            fitButton
        )
        controlsView.addSubview(
            zoomInButton
        )
    }

    func configureButton(
        _ button: NSButton,
        symbolName: String,
        fallbackTitle: String,
        action: Selector
    ) {
        button.target = self
        button.action = action
        button.bezelStyle = .texturedRounded
        button.setButtonType(
            .momentaryPushIn
        )
        button.imageScaling = .scaleProportionallyDown
        button.focusRingType = .none

        if let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: fallbackTitle
        ) {
            button.title = ""
            button.image = image
            button.imagePosition = .imageOnly
        } else {
            button.title = fallbackTitle
        }
    }

    func layoutControls() {
        let buttonSize: CGFloat = 28
        let spacing: CGFloat = 4
        let padding: CGFloat = 6
        let inset: CGFloat = 18

        let width = padding * 2 + buttonSize * 3 + spacing * 2
        let height = padding * 2 + buttonSize

        controlsView.frame = NSRect(
            x: max(
                inset,
                bounds.maxX - inset - width
            ),
            y: max(
                inset,
                bounds.maxY - inset - height
            ),
            width: width,
            height: height
        )

        zoomOutButton.frame = NSRect(
            x: padding,
            y: padding,
            width: buttonSize,
            height: buttonSize
        )

        fitButton.frame = NSRect(
            x: padding + buttonSize + spacing,
            y: padding,
            width: buttonSize,
            height: buttonSize
        )

        zoomInButton.frame = NSRect(
            x: padding + buttonSize * 2 + spacing * 2,
            y: padding,
            width: buttonSize,
            height: buttonSize
        )
    }

    @objc
    func zoomOutPressed(
        _ sender: Any?
    ) {
        do {
            try zoom(
                by: 0.8,
                around: DrawingCoordinate(
                    x: Double(bounds.midX),
                    y: Double(bounds.midY)
                )
            )
        } catch {
            fputs(
                "DrawingboardHostNetworkProbeView zoom out failed: \(error.localizedDescription)\n",
                stderr
            )
        }
    }

    @objc
    func fitPressed(
        _ sender: Any?
    ) {
        do {
            followsWindowFit = true
            viewport = try fittedViewport()
            needsDisplay = true
        } catch {
            fputs(
                "DrawingboardHostNetworkProbeView fit failed: \(error.localizedDescription)\n",
                stderr
            )
        }
    }

    @objc
    func zoomInPressed(
        _ sender: Any?
    ) {
        do {
            try zoom(
                by: 1.25,
                around: DrawingCoordinate(
                    x: Double(bounds.midX),
                    y: Double(bounds.midY)
                )
            )
        } catch {
            fputs(
                "DrawingboardHostNetworkProbeView zoom in failed: \(error.localizedDescription)\n",
                stderr
            )
        }
    }
}

private extension DrawingboardHostNetworkProbeView {
    func currentViewport() throws -> DrawingViewport {
        if followsWindowFit {
            let fitted = try fittedViewport()
            viewport = fitted

            return fitted
        }

        if let viewport {
            return viewport
        }

        let fitted = try fittedViewport()
        viewport = fitted

        return fitted
    }

    func fittedViewport() throws -> DrawingViewport {
        try DrawingViewport.fitPage(
            pageSize: pageSize,
            viewSize: currentViewSize(),
            margin: 24
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

    func resizeViewportToCurrentBoundsIfNeeded() {
        do {
            guard let viewport else {
                return
            }

            let nextViewSize = try currentViewSize()

            guard viewport.viewSize != nextViewSize else {
                return
            }

            let oldCenter = DrawingCoordinate(
                x: viewport.viewSize.width / 2,
                y: viewport.viewSize.height / 2
            )
            let pageCenter = viewport.viewToPage(
                oldCenter
            )

            self.viewport = try DrawingViewport(
                pageSize: viewport.pageSize,
                viewSize: nextViewSize,
                scale: viewport.scale,
                offset: DrawingVector(
                    dx: nextViewSize.width / 2 - pageCenter.x * viewport.scale,
                    dy: nextViewSize.height / 2 - pageCenter.y * viewport.scale
                )
            )
        } catch {
            fputs(
                "DrawingboardHostNetworkProbeView resize viewport failed: \(error.localizedDescription)\n",
                stderr
            )
        }
    }

    func zoom(
        by factor: Double,
        around anchor: DrawingCoordinate
    ) throws {
        let base = try currentViewport()
        let fitted = try fittedViewport()

        let minimumScale = fitted.scale * 0.35
        let maximumScale = fitted.scale * 8

        let requestedScale = base.scale * factor
        let nextScale = min(
            max(
                requestedScale,
                minimumScale
            ),
            maximumScale
        )

        let actualFactor = nextScale / base.scale

        viewport = try base.zoomed(
            by: actualFactor,
            around: anchor
        )

        followsWindowFit = false
        needsDisplay = true
    }

    func pan(
        by delta: DrawingVector
    ) throws {
        let base = try currentViewport()

        viewport = try base.panned(
            by: delta
        )

        followsWindowFit = false
        needsDisplay = true
    }
}

private extension DrawingboardHostNetworkProbeView {
    func drawPageBackground(
        viewport: DrawingViewport
    ) {
        let origin = viewport.pageToView(
            DrawingCoordinate(
                x: 0,
                y: 0
            )
        )
        let farCorner = viewport.pageToView(
            DrawingCoordinate(
                x: viewport.pageSize.width,
                y: viewport.pageSize.height
            )
        )

        let rect = NSRect(
            x: origin.x,
            y: origin.y,
            width: farCorner.x - origin.x,
            height: farCorner.y - origin.y
        )

        NSColor(
            calibratedWhite: 0.96,
            alpha: 1
        ).setFill()
        rect.fill()

        NSColor(
            calibratedWhite: 0.82,
            alpha: 1
        ).setStroke()

        let border = NSBezierPath(
            rect: rect
        )
        border.lineWidth = 1
        border.stroke()
    }

    func drawCommands(
        frame: DrawingRenderFrame
    ) {
        for command in frame.commands {
            switch command {
            case .stroke(let stroke):
                drawStroke(
                    stroke
                )
            }
        }
    }

    func drawStroke(
        _ stroke: DrawingRenderStrokeCommand
    ) {
        guard let first = stroke.points.first else {
            return
        }

        let path = NSBezierPath()
        path.move(
            to: NSPoint(
                x: first.x,
                y: first.y
            )
        )

        for point in stroke.points.dropFirst() {
            path.line(
                to: NSPoint(
                    x: point.x,
                    y: point.y
                )
            )
        }

        path.lineWidth = stroke.width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        NSColor(
            calibratedRed: stroke.color.r,
            green: stroke.color.g,
            blue: stroke.color.b,
            alpha: stroke.color.a
        ).setStroke()

        path.stroke()
    }
}
