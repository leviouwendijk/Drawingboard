import DrawingboardCore
import DrawingboardNetworkTransport
import DrawingboardPadRuntime
import Foundation

public final class DrawingPadNetworkSession: @unchecked Sendable {
    public let page: DrawingPageIdentifier
    public let pageSize: DrawingSize
    public let tool: DrawingTool
    public let client: DrawingNetworkPadClient
    public let runtime: DrawingPadAppRuntime

    public init(
        host: String,
        port: UInt16 = 47_777,
        page: DrawingPageIdentifier,
        pageSize: DrawingSize,
        tool: DrawingTool,
        maximumPointCount: Int = 8
    ) throws {
        self.page = page
        self.pageSize = pageSize
        self.tool = tool

        let client = try DrawingNetworkPadClient(
            host: host,
            port: port
        )

        self.client = client

        self.runtime = try DrawingPadAppRuntime(
            page: page,
            tool: tool,
            maximumPointCount: maximumPointCount
        ) { [client] message in
            try await client.send(
                message
            )
        }
    }

    public func start() {
        client.start()
    }

    public func close() {
        client.close()
    }

    public func connect() async throws {
        try await client.connect()
    }
}
