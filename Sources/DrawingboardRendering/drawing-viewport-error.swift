import Foundation

public enum DrawingViewportError: Error, Sendable, LocalizedError, Equatable {
    case invalidScale(Double)
    case invalidZoomFactor(Double)
    case invalidMargin(Double)
    case viewportTooSmall(width: Double, height: Double, margin: Double)

    public var errorDescription: String? {
        switch self {
        case .invalidScale(let scale):
            "Invalid viewport scale: \(scale)."

        case .invalidZoomFactor(let factor):
            "Invalid zoom factor: \(factor)."

        case .invalidMargin(let margin):
            "Invalid viewport margin: \(margin)."

        case .viewportTooSmall(let width, let height, let margin):
            "Viewport \(width)x\(height) is too small for margin \(margin)."
        }
    }
}
