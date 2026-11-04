import Foundation

// Old fixtures are never deleted, so the decoder keeps handling every
// format it has seen
enum Fixture {
    static let normal = "2.1.317-normal"
    static let loggedOut = "2.1.317-logged-out"
    static let apiKey = "2.1.317-api-key"
    static let noHome = "2.1.317-no-home"

    struct Missing: Error {
        let name: String
    }

    static func url(_ name: String) throws -> URL {
        guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "jsonl") else {
            throw Missing(name: name)
        }
        return url
    }

    static func lines(_ name: String) throws -> [String] {
        try String(contentsOf: url(name), encoding: .utf8).components(separatedBy: "\n")
    }
}

private final class BundleToken {}
