import Foundation

public protocol HTTPClient: Sendable {
    func fetchData(from url: URL) async throws -> Data
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func fetchData(from url: URL) async throws -> Data {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  200..<300 ~= http.statusCode else {
                throw TranslationError.network
            }
            return data
        } catch let error as TranslationError {
            throw error
        } catch {
            throw TranslationError.network
        }
    }
}
