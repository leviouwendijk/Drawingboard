import Foundation

public struct DrawingPage: Sendable, Codable, Hashable, Identifiable {
    public let id: DrawingPageIdentifier
    public let size: DrawingSize
    public var strokes: [DrawingStroke]

    public init(
        id: DrawingPageIdentifier = .next(),
        size: DrawingSize,
        strokes: [DrawingStroke] = []
    ) {
        self.id = id
        self.size = size
        self.strokes = strokes
    }
}
