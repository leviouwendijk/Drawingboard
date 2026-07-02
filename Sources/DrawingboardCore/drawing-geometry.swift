import Foundation

public struct DrawingSize: Sendable, Codable, Hashable {
    public let width: Double
    public let height: Double

    public init(
        width: Double,
        height: Double
    ) throws {
        guard width > 0,
              height > 0,
              width.isFinite,
              height.isFinite else {
            throw DrawingError.invalidSize(
                width: width,
                height: height
            )
        }

        self.width = width
        self.height = height
    }
}

public struct DrawingPoint: Sendable, Codable, Hashable {
    public let x: Double
    public let y: Double
    public let time: TimeInterval
    public let force: Double?
    public let altitude: Double?
    public let azimuth: Double?
    public let predicted: Bool

    public init(
        x: Double,
        y: Double,
        time: TimeInterval,
        force: Double? = nil,
        altitude: Double? = nil,
        azimuth: Double? = nil,
        predicted: Bool = false
    ) {
        self.x = x
        self.y = y
        self.time = time
        self.force = force
        self.altitude = altitude
        self.azimuth = azimuth
        self.predicted = predicted
    }
}
