import Foundation

public enum DrawingTransportKind: String, Sendable, Codable, Hashable, CaseIterable {
    case direct_wired
    case network_bonjour
    case multipeer
    case loopback
}

public struct DrawingTransportPreference: Sendable, Codable, Hashable {
    public let preferred: [DrawingTransportKind]

    public init(
        preferred: [DrawingTransportKind]
    ) {
        self.preferred = preferred
    }

    public static let standard = DrawingTransportPreference(
        preferred: [
            .direct_wired,
            .network_bonjour,
            .multipeer,
        ]
    )

    public static let test = DrawingTransportPreference(
        preferred: [
            .loopback,
        ]
    )
}
