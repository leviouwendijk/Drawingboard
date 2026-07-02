import Foundation

public enum DrawingError: Error, Sendable, LocalizedError, Equatable {
    case invalidSize(width: Double, height: Double)
    case invalidColorChannel(name: String, value: Double)
    case invalidStrokeWidth(Double)
    case emptyStroke
    case missingPage(String)
    case duplicatePage(String)
    case missingOpenStroke(String)
    case duplicateOpenStroke(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSize(let width, let height):
            "Invalid drawing size: \(width)x\(height)."

        case .invalidColorChannel(let name, let value):
            "Invalid color channel \(name): \(value)."

        case .invalidStrokeWidth(let width):
            "Invalid stroke width: \(width)."

        case .emptyStroke:
            "A stroke must contain at least one point."

        case .missingPage(let id):
            "Missing page: \(id)."

        case .duplicatePage(let id):
            "Duplicate page: \(id)."

        case .missingOpenStroke(let id):
            "Missing open stroke: \(id)."

        case .duplicateOpenStroke(let id):
            "Duplicate open stroke: \(id)."
        }
    }
}
