import Foundation
import Primitives

public struct DrawingDocumentIdentifier: StringIdentifier {
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public static func next() -> Self {
        Self(
            UUID().uuidString
        )
    }
}

public struct DrawingPageIdentifier: StringIdentifier {
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public static func next() -> Self {
        Self(
            UUID().uuidString
        )
    }
}

public struct DrawingStrokeIdentifier: StringIdentifier {
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public static func next() -> Self {
        Self(
            UUID().uuidString
        )
    }
}

public struct DrawingSessionIdentifier: StringIdentifier {
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }

    public static func next() -> Self {
        Self(
            UUID().uuidString
        )
    }
}
