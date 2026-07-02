public struct DrawingDocument: Sendable, Codable, Hashable, Identifiable {
    public let id: DrawingDocumentIdentifier
    public var pages: [DrawingPage]
    public var activePage: DrawingPageIdentifier

    public init(
        id: DrawingDocumentIdentifier = .next(),
        pages: [DrawingPage],
        activePage: DrawingPageIdentifier
    ) throws {
        guard pages.contains(where: { $0.id == activePage }) else {
            throw DrawingError.missingPage(
                activePage.rawValue
            )
        }

        self.id = id
        self.pages = pages
        self.activePage = activePage
    }

    public static func blank(
        page: DrawingPageIdentifier = .next(),
        size: DrawingSize
    ) throws -> DrawingDocument {
        let page = DrawingPage(
            id: page,
            size: size
        )

        return try DrawingDocument(
            pages: [
                page,
            ],
            activePage: page.id
        )
    }
}
