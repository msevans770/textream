import Foundation

enum LinkedScriptError: Error, LocalizedError {
    case bookmarkInvalid
    case unreadable(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .bookmarkInvalid: return "The link to the script file is no longer valid."
        case .unreadable(let reason): return "The script file could not be read: \(reason)"
        case .empty: return "The script file has no readable text."
        }
    }
}

enum LinkedScriptStore {
    static func makeBookmark(for url: URL) throws -> Data { throw LinkedScriptError.bookmarkInvalid }
    static func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) { throw LinkedScriptError.bookmarkInvalid }
    static func loadPages(from url: URL) throws -> [String] { throw LinkedScriptError.empty }
}
