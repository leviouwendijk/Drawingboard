import DrawingboardCore
import DrawingboardPadNetworkRuntime
import Foundation

@main
struct DrawingboardPadNetworkProbe {
    static func main() async throws {
        let host = CommandLine.arguments.dropFirst().first ?? "127.0.0.1"

        let page = DrawingPageIdentifier(
            "probe-page"
        )

        let session = try DrawingPadNetworkSession(
            host: host,
            port: 47_777,
            page: page,
            pageSize: try DrawingSize(
                width: 1280,
                height: 720
            ),
            tool: DrawingTool(
                kind: .pen,
                color: .black,
                width: 5
            ),
            maximumPointCount: 2
        )

        try await session.connect()

        defer {
            session.close()
        }

        print(
            "DrawingboardPadNetworkProbe ready on \(host):47777"
        )

        let stroke = DrawingStrokeIdentifier(
            "network-probe-stroke"
        )

        try await session.runtime.begin(
            stroke: stroke,
            at: DrawingPoint(
                x: 120,
                y: 140,
                time: 0
            )
        )

        try await sleepFrame()

        try await session.runtime.append(
            points: [
                DrawingPoint(
                    x: 220,
                    y: 180,
                    time: 0.01
                ),
            ]
        )

        try await sleepFrame()

        try await session.runtime.append(
            points: [
                DrawingPoint(
                    x: 320,
                    y: 120,
                    time: 0.02
                ),
                DrawingPoint(
                    x: 440,
                    y: 260,
                    time: 0.03
                ),
            ]
        )

        try await sleepFrame()

        try await session.runtime.append(
            points: [
                DrawingPoint(
                    x: 620,
                    y: 220,
                    time: 0.04
                ),
                DrawingPoint(
                    x: 760,
                    y: 360,
                    time: 0.05
                ),
            ]
        )

        try await sleepFrame()

        try await session.runtime.end(
            points: [
                DrawingPoint(
                    x: 920,
                    y: 300,
                    time: 0.06
                ),
                DrawingPoint(
                    x: 1040,
                    y: 380,
                    time: 0.07
                ),
            ]
        )

        try await Task.sleep(
            nanoseconds: 300_000_000
        )

        print(
            "DrawingboardPadNetworkProbe sent stroke"
        )
    }

    private static func sleepFrame() async throws {
        try await Task.sleep(
            nanoseconds: 120_000_000
        )
    }
}
