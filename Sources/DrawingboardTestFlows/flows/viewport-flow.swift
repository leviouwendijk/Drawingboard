import DrawingboardCore
import DrawingboardRendering
import TestFlows

let viewportFlow = TestFlow(
    "viewport.transform",
    title: "Viewport transform"
) {
    let pageSize = try DrawingSize(
        width: 1000,
        height: 500
    )
    let viewSize = try DrawingSize(
        width: 1200,
        height: 800
    )

    let viewport = try DrawingViewport.fitPage(
        pageSize: pageSize,
        viewSize: viewSize,
        margin: 100
    )

    try Expect.equal(
        viewport.scale,
        1.0,
        "fit scale uses available height"
    )

    try Expect.equal(
        viewport.offset.dx,
        100,
        "fit centers page horizontally"
    )

    try Expect.equal(
        viewport.offset.dy,
        150,
        "fit centers page vertically"
    )

    let pagePoint = DrawingCoordinate(
        x: 200,
        y: 100
    )

    let viewPoint = viewport.pageToView(
        pagePoint
    )

    try Expect.equal(
        viewPoint,
        DrawingCoordinate(
            x: 300,
            y: 250
        ),
        "page coordinate converts to view coordinate"
    )

    try Expect.equal(
        viewport.viewToPage(
            viewPoint
        ),
        pagePoint,
        "view coordinate converts back to page coordinate"
    )

    let panned = try viewport.panned(
        by: DrawingVector(
            dx: 10,
            dy: -20
        )
    )

    try Expect.equal(
        panned.offset,
        DrawingVector(
            dx: 110,
            dy: 130
        ),
        "pan adjusts viewport offset"
    )

    let zoomAnchor = DrawingCoordinate(
        x: 300,
        y: 250
    )
    let zoomed = try viewport.zoomed(
        by: 2,
        around: zoomAnchor
    )

    try Expect.equal(
        zoomed.viewToPage(
            zoomAnchor
        ),
        viewport.viewToPage(
            zoomAnchor
        ),
        "zoom preserves page coordinate under anchor"
    )

    return []
}
