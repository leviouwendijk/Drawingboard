import DrawingboardCore
import DrawingboardRendering
import Foundation

typealias DrawingboardHostExportError = DrawingboardExportError
typealias DrawingboardHostExportResult = DrawingboardExportResult

struct DrawingboardHostExporter {
    static func defaultExportDirectory() -> URL {
        DrawingboardExporter.defaultExportDirectory()
    }

    @discardableResult
    static func exportActiveScenePNG(
        state: DrawingDocumentState,
        to directory: URL = defaultExportDirectory(),
        scale: Double = 2
    ) throws -> DrawingboardHostExportResult {
        try DrawingboardExporter.exportActiveScenePNG(
            state: state,
            to: directory,
            scale: scale
        )
    }

    @discardableResult
    static func exportAllScenesPNG(
        state: DrawingDocumentState,
        to directory: URL = defaultExportDirectory(),
        scale: Double = 2
    ) throws -> DrawingboardHostExportResult {
        try DrawingboardExporter.exportAllScenesPNG(
            state: state,
            to: directory,
            scale: scale
        )
    }

    @discardableResult
    static func exportActiveScenePDF(
        state: DrawingDocumentState,
        to directory: URL = defaultExportDirectory()
    ) throws -> DrawingboardHostExportResult {
        try DrawingboardExporter.exportActiveScenePDF(
            state: state,
            to: directory
        )
    }

    @discardableResult
    static func exportAllScenesPDF(
        state: DrawingDocumentState,
        to directory: URL = defaultExportDirectory()
    ) throws -> DrawingboardHostExportResult {
        try DrawingboardExporter.exportAllScenesPDF(
            state: state,
            to: directory
        )
    }
}
