import DrawingboardCore
import DrawingboardRendering
import TestFlows

let renderCommandFlow = TestFlow(
    "render.commands",
    title: "Render commands"
) {
    let pageSize = try DrawingSize(
        width: 100,
        height: 100
    )
    let viewSize = try DrawingSize(
        width: 200,
        height: 200
    )
    let page = DrawingPageIdentifier(
        "page-1"
    )
    let document = try DrawingDocument.blank(
        page: page,
        size: pageSize
    )
    let tool = try DrawingTool(
        kind: .pen,
        color: .black,
        width: 4
    )
    let finishedStroke = DrawingStrokeIdentifier(
        "stroke-finished"
    )
    let openStroke = DrawingStrokeIdentifier(
        "stroke-open"
    )

    var state = DrawingDocumentState(
        document: document
    )
    let reducer = DrawingDocumentReducer()

    try reducer.apply(
        .stroke_began(
            try DrawingStroke(
                id: finishedStroke,
                page: page,
                tool: tool,
                points: [
                    DrawingPoint(
                        x: 10,
                        y: 10,
                        time: 0
                    ),
                ]
            )
        ),
        to: &state
    )

    try reducer.apply(
        .stroke_ended(
            DrawingStrokeEnd(
                stroke: finishedStroke,
                points: [
                    DrawingPoint(
                        x: 20,
                        y: 30,
                        time: 0.01
                    ),
                ]
            )
        ),
        to: &state
    )

    try reducer.apply(
        .stroke_began(
            try DrawingStroke(
                id: openStroke,
                page: page,
                tool: tool,
                points: [
                    DrawingPoint(
                        x: 40,
                        y: 50,
                        time: 0.02
                    ),
                ]
            )
        ),
        to: &state
    )

    let viewport = try DrawingViewport(
        pageSize: pageSize,
        viewSize: viewSize,
        scale: 2,
        offset: DrawingVector(
            dx: 10,
            dy: 20
        )
    )

    let frame = try DrawingRenderCommandResolver().resolve(
        state: state,
        viewport: viewport
    )

    try Expect.equal(
        frame.page,
        page,
        "render frame targets active page"
    )

    try Expect.equal(
        frame.commands.count,
        2,
        "render frame includes finished and open strokes"
    )

    guard case .stroke(let firstCommand) = frame.commands[0] else {
        throw DrawingRenderError.emptyRenderedStroke(
            "missing-first-command"
        )
    }

    try Expect.equal(
        firstCommand.id,
        finishedStroke,
        "finished stroke is rendered first"
    )

    try Expect.equal(
        firstCommand.isOpen,
        false,
        "finished stroke is not marked open"
    )

    try Expect.equal(
        firstCommand.width,
        8,
        "rendered stroke width scales with viewport"
    )

    try Expect.equal(
        firstCommand.points[0],
        DrawingCoordinate(
            x: 30,
            y: 40
        ),
        "render command converts point to view coordinates"
    )

    guard case .stroke(let secondCommand) = frame.commands[1] else {
        throw DrawingRenderError.emptyRenderedStroke(
            "missing-second-command"
        )
    }

    try Expect.equal(
        secondCommand.id,
        openStroke,
        "open stroke is rendered after finished strokes"
    )

    try Expect.equal(
        secondCommand.isOpen,
        true,
        "open stroke is marked open"
    )

    return []
}
