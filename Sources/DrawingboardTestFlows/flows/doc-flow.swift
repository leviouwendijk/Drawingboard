import DrawingboardCore
import TestFlows

let documentFlow = TestFlow(
    "document.reducer",
    title: "Document reducer"
) {
    let size = try DrawingSize(
        width: 100,
        height: 80
    )
    let page = DrawingPageIdentifier(
        "page-1"
    )
    let document = try DrawingDocument.blank(
        page: page,
        size: size
    )
    let reducer = DrawingDocumentReducer()
    let tool = try DrawingTool(
        kind: .pen,
        color: .black,
        width: 4
    )
    let strokeID = DrawingStrokeIdentifier(
        "stroke-1"
    )

    var state = DrawingDocumentState(
        document: document
    )

    try reducer.apply(
        .stroke_began(
            try DrawingStroke(
                id: strokeID,
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
        .stroke_moved(
            DrawingStrokeMove(
                stroke: strokeID,
                points: [
                    DrawingPoint(
                        x: 12,
                        y: 14,
                        time: 0.01
                    ),
                ]
            )
        ),
        to: &state
    )

    try reducer.apply(
        .stroke_ended(
            DrawingStrokeEnd(
                stroke: strokeID,
                points: [
                    DrawingPoint(
                        x: 18,
                        y: 20,
                        time: 0.02
                    ),
                ]
            )
        ),
        to: &state
    )

    try Expect.equal(
        state.openStrokes.count,
        0,
        "open strokes are cleared"
    )
    try Expect.equal(
        state.document.pages[0].strokes.count,
        1,
        "finished stroke is stored"
    )
    try Expect.equal(
        state.document.pages[0].strokes[0].points.count,
        3,
        "stroke points are accumulated"
    )

    return []
}
