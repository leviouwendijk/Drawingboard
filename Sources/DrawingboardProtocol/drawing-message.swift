import DrawingboardCore
import Foundation
import Version

public enum DrawingPeerRole: String, Sendable, Codable, Hashable, CaseIterable {
    case host
    case pad
}

public struct DrawingHello: Sendable, Codable, Equatable {
    public let version: ObjectVersion
    public let role: DrawingPeerRole
    public let deviceName: String

    public init(
        version: ObjectVersion = .default_version(),
        role: DrawingPeerRole,
        deviceName: String
    ) {
        self.version = version
        self.role = role
        self.deviceName = deviceName
    }
}

public struct DrawingSessionAccepted: Sendable, Codable, Equatable {
    public let session: DrawingSessionIdentifier
    public let document: DrawingDocumentIdentifier
    public let activePage: DrawingPageIdentifier
    public let canvasSize: DrawingSize

    public init(
        session: DrawingSessionIdentifier,
        document: DrawingDocumentIdentifier,
        activePage: DrawingPageIdentifier,
        canvasSize: DrawingSize
    ) {
        self.session = session
        self.document = document
        self.activePage = activePage
        self.canvasSize = canvasSize
    }
}

public enum DrawingMessage: Sendable, Codable, Equatable {
    case hello(DrawingHello)
    case session_accepted(DrawingSessionAccepted)
    case event(DrawingEvent)
    case snapshot(DrawingDocument)
}
