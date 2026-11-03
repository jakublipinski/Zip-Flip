import Foundation

/// One HTTP answer, reduced to what the sheet client looks at.
public struct HTTPReply: Sendable {
    public let data: Data
    public let status: Int
    /// Header names lower-cased.
    public let headers: [String: String]
    /// Where the response came from after redirects.
    public let finalURL: URL?

    public init(data: Data, status: Int, headers: [String: String], finalURL: URL?) {
        self.data = data
        self.status = status
        self.headers = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
        self.finalURL = finalURL
    }

    public var contentType: String? { headers["content-type"] }
    public var contentDisposition: String? { headers["content-disposition"] }
    public var text: String { String(decoding: data, as: UTF8.self) }
}

/// The sheet client talks to the network through this, so tests can answer
/// with canned replies.
public protocol HTTPTransport: Sendable {
    func get(_ url: URL) async throws -> HTTPReply
}

public struct URLSessionTransport: HTTPTransport {
    public let session: URLSession
    public let timeout: TimeInterval

    public init(session: URLSession = .shared, timeout: TimeInterval = 30) {
        self.session = session
        self.timeout = timeout
    }

    public func get(_ url: URL) async throws -> HTTPReply {
        var request = URLRequest(url: url)
        // Google marks everything no-store anyway; never serve a stale copy from URLCache.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let k = key as? String, let v = value as? String { headers[k.lowercased()] = v }
        }
        return HTTPReply(data: data, status: http.statusCode, headers: headers, finalURL: http.url)
    }
}
