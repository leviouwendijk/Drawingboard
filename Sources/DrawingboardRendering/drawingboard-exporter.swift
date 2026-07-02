import CoreGraphics
import DrawingboardCore
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum DrawingboardExportError: Error, Sendable, LocalizedError {
    case missingPage(String)
    case emptyDocument
    case cannotCreateBitmapContext
    case cannotCreateImage
    case cannotEncodePNG
    case cannotCreatePDFContext(URL)

    public var errorDescription: String? {
        switch self {
        case .missingPage(let id):
            "Missing page: \(id)."

        case .emptyDocument:
            "Cannot export an empty document."

        case .cannotCreateBitmapContext:
            "Could not create bitmap export context."

        case .cannotCreateImage:
            "Could not create exported image."

        case .cannotEncodePNG:
            "Could not encode PNG."

        case .cannotCreatePDFContext(let url):
            "Could not create PDF context at \(url.path)."
        }
    }
}

public struct DrawingboardExportResult: Sendable, Hashable {
    public let urls: [URL]

    public init(
        urls: [URL]
    ) {
        self.urls = urls
    }
}

public struct DrawingboardExporter {
    public static func defaultExportDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "drawingboard-export",
                isDirectory: true
            )
    }

    @discardableResult
    public static func exportActiveScenePNG(
        state: DrawingDocumentState,
        to directory: URL = defaultExportDirectory(),
        scale: Double = 2
    ) throws -> DrawingboardExportResult {
        try prepareDirectory(
            directory
        )

        let page = try activePage(
            in: state.document
        )
        let index = pageIndex(
            page.id,
            in: state.document
        )

        let url = directory.appendingPathComponent(
            sceneFileName(
                prefix: "drawingboard-scene",
                index: index,
                extension: "png"
            )
        )

        let data = try pngData(
            state: state,
            page: page,
            scale: scale
        )

        try data.write(
            to: url,
            options: .atomic
        )

        return DrawingboardExportResult(
            urls: [
                url,
            ]
        )
    }

    @discardableResult
    public static func exportAllScenesPNG(
        state: DrawingDocumentState,
        to directory: URL = defaultExportDirectory(),
        scale: Double = 2
    ) throws -> DrawingboardExportResult {
        try prepareDirectory(
            directory
        )

        var urls: [URL] = []

        for page in state.document.pages {
            let index = pageIndex(
                page.id,
                in: state.document
            )

            let url = directory.appendingPathComponent(
                sceneFileName(
                    prefix: "drawingboard-scene",
                    index: index,
                    extension: "png"
                )
            )

            let data = try pngData(
                state: state,
                page: page,
                scale: scale
            )

            try data.write(
                to: url,
                options: .atomic
            )

            urls.append(
                url
            )
        }

        return DrawingboardExportResult(
            urls: urls
        )
    }

    @discardableResult
    public static func exportActiveScenePDF(
        state: DrawingDocumentState,
        to directory: URL = defaultExportDirectory()
    ) throws -> DrawingboardExportResult {
        try prepareDirectory(
            directory
        )

        let page = try activePage(
            in: state.document
        )
        let index = pageIndex(
            page.id,
            in: state.document
        )

        let url = directory.appendingPathComponent(
            sceneFileName(
                prefix: "drawingboard-scene",
                index: index,
                extension: "pdf"
            )
        )

        try writePDF(
            state: state,
            pages: [
                page,
            ],
            to: url
        )

        return DrawingboardExportResult(
            urls: [
                url,
            ]
        )
    }

    @discardableResult
    public static func exportAllScenesPDF(
        state: DrawingDocumentState,
        to directory: URL = defaultExportDirectory()
    ) throws -> DrawingboardExportResult {
        try prepareDirectory(
            directory
        )

        let url = directory.appendingPathComponent(
            "drawingboard-scenes.pdf"
        )

        try writePDF(
            state: state,
            pages: state.document.pages,
            to: url
        )

        return DrawingboardExportResult(
            urls: [
                url,
            ]
        )
    }
}

private extension DrawingboardExporter {
    static func prepareDirectory(
        _ directory: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    static func activePage(
        in document: DrawingDocument
    ) throws -> DrawingPage {
        guard let page = document.pages.first(where: { page in
            page.id == document.activePage
        }) else {
            throw DrawingboardExportError.missingPage(
                document.activePage.rawValue
            )
        }

        return page
    }

    static func pageIndex(
        _ page: DrawingPageIdentifier,
        in document: DrawingDocument
    ) -> Int {
        document.pages.firstIndex { candidate in
            candidate.id == page
        } ?? 0
    }

    static func sceneFileName(
        prefix: String,
        index: Int,
        extension fileExtension: String
    ) -> String {
        let number = String(
            format: "%03d",
            index + 1
        )

        return "\(prefix)-\(number).\(fileExtension)"
    }

    static func renderFrame(
        state: DrawingDocumentState,
        page: DrawingPage,
        scale: Double
    ) throws -> DrawingRenderFrame {
        var document = state.document
        document.activePage = page.id

        var openStrokes: [DrawingStrokeIdentifier: DrawingStroke] = [:]

        for (id, stroke) in state.openStrokes where stroke.page == page.id {
            openStrokes[id] = stroke
        }

        let pageState = DrawingDocumentState(
            document: document,
            openStrokes: openStrokes
        )

        let viewSize = try DrawingSize(
            width: page.size.width * scale,
            height: page.size.height * scale
        )

        let viewport = try DrawingViewport.fitPage(
            pageSize: page.size,
            viewSize: viewSize,
            margin: 0
        )

        return try DrawingRenderCommandResolver().resolve(
            state: pageState,
            viewport: viewport
        )
    }
}

private extension DrawingboardExporter {
    static func pngData(
        state: DrawingDocumentState,
        page: DrawingPage,
        scale: Double
    ) throws -> Data {
        let frame = try renderFrame(
            state: state,
            page: page,
            scale: scale
        )

        let width = Int(
            ceil(
                page.size.width * scale
            )
        )
        let height = Int(
            ceil(
                page.size.height * scale
            )
        )
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue |
            CGBitmapInfo.byteOrder32Big.rawValue

        var storage = Data(
            count: bytesPerRow * height
        )

        return try storage.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                      data: baseAddress,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow,
                      space: colorSpace,
                      bitmapInfo: bitmapInfo
                  ) else {
                throw DrawingboardExportError.cannotCreateBitmapContext
            }

            draw(
                frame: frame,
                width: Double(width),
                height: Double(height),
                in: context
            )

            guard let image = context.makeImage() else {
                throw DrawingboardExportError.cannotCreateImage
            }

            let data = NSMutableData()

            guard let destination = CGImageDestinationCreateWithData(
                data,
                UTType.png.identifier as CFString,
                1,
                nil
            ) else {
                throw DrawingboardExportError.cannotEncodePNG
            }

            CGImageDestinationAddImage(
                destination,
                image,
                nil
            )

            guard CGImageDestinationFinalize(
                destination
            ) else {
                throw DrawingboardExportError.cannotEncodePNG
            }

            return data as Data
        }
    }

    static func writePDF(
        state: DrawingDocumentState,
        pages: [DrawingPage],
        to url: URL
    ) throws {
        guard let firstPage = pages.first else {
            throw DrawingboardExportError.emptyDocument
        }

        var mediaBox = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(firstPage.size.width),
            height: CGFloat(firstPage.size.height)
        )

        guard let context = CGContext(
            url as CFURL,
            mediaBox: &mediaBox,
            nil
        ) else {
            throw DrawingboardExportError.cannotCreatePDFContext(
                url
            )
        }

        for page in pages {
            let frame = try renderFrame(
                state: state,
                page: page,
                scale: 1
            )

            context.beginPDFPage(
                nil
            )

            draw(
                frame: frame,
                width: page.size.width,
                height: page.size.height,
                in: context
            )

            context.endPDFPage()
        }

        context.closePDF()
    }

    static func draw(
        frame: DrawingRenderFrame,
        width: Double,
        height: Double,
        in context: CGContext
    ) {
        context.saveGState()

        context.translateBy(
            x: 0,
            y: CGFloat(height)
        )
        context.scaleBy(
            x: 1,
            y: -1
        )

        context.setFillColor(
            red: 1,
            green: 1,
            blue: 1,
            alpha: 1
        )
        context.fill(
            CGRect(
                x: 0,
                y: 0,
                width: CGFloat(width),
                height: CGFloat(height)
            )
        )

        for command in frame.commands {
            switch command {
            case .stroke(let stroke):
                draw(
                    stroke: stroke,
                    in: context
                )
            }
        }

        context.restoreGState()
    }

    static func draw(
        stroke: DrawingRenderStrokeCommand,
        in context: CGContext
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
            red: CGFloat(stroke.color.r),
            green: CGFloat(stroke.color.g),
            blue: CGFloat(stroke.color.b),
            alpha: CGFloat(stroke.color.a)
        )
        context.strokePath()

        context.restoreGState()
    }
}
