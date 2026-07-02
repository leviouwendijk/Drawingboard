import AppKit
import DrawingboardCore
import DrawingboardRendering
import Foundation

@MainActor
final class DrawingboardReplayProbeView: NSView {
    private var renderFrame: DrawingRenderFrame

    init(
        frame frameRect: NSRect,
        renderFrame: DrawingRenderFrame
    ) {
        self.renderFrame = renderFrame

        super.init(
            frame: frameRect
        )

        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
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
        renderFrame: DrawingRenderFrame
    ) {
        self.renderFrame = renderFrame
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

        drawPageBackground()
        drawCommands()
    }
}

private extension DrawingboardReplayProbeView {
    func drawPageBackground() {
        let viewport = renderFrame.viewport

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

    func drawCommands() {
        for command in renderFrame.commands {
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
