import Foundation

public enum DrawingToolKind: String, Sendable, Codable, Hashable, CaseIterable {
    case pen
    case marker
    case eraser
}

public struct DrawingRGBA: Sendable, Codable, Hashable {
    public let r: Double
    public let g: Double
    public let b: Double
    public let a: Double

    public init(
        r: Double,
        g: Double,
        b: Double,
        a: Double = 1
    ) throws {
        try Self.validate(
            r,
            name: "r"
        )
        try Self.validate(
            g,
            name: "g"
        )
        try Self.validate(
            b,
            name: "b"
        )
        try Self.validate(
            a,
            name: "a"
        )

        self.init(
            uncheckedR: r,
            g: g,
            b: b,
            a: a
        )
    }

    private init(
        uncheckedR r: Double,
        g: Double,
        b: Double,
        a: Double
    ) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public static let black = DrawingRGBA(
        uncheckedR: 0,
        g: 0,
        b: 0,
        a: 1
    )

    public static let white = DrawingRGBA(
        uncheckedR: 1,
        g: 1,
        b: 1,
        a: 1
    )

    private static func validate(
        _ value: Double,
        name: String
    ) throws {
        guard value >= 0,
              value <= 1,
              value.isFinite else {
            throw DrawingError.invalidColorChannel(
                name: name,
                value: value
            )
        }
    }
}

public struct DrawingTool: Sendable, Codable, Hashable {
    public let kind: DrawingToolKind
    public let color: DrawingRGBA
    public let width: Double

    public init(
        kind: DrawingToolKind = .pen,
        color: DrawingRGBA = .black,
        width: Double = 4
    ) throws {
        guard width > 0,
              width.isFinite else {
            throw DrawingError.invalidStrokeWidth(
                width
            )
        }

        self.kind = kind
        self.color = color
        self.width = width
    }
}
