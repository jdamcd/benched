import Foundation

// The usage report is experimental, so it's read field by field from this
// rather than through a strict Codable model that fails on the first surprise.
enum JSONValue: Sendable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init?(jsonLine: String) {
        guard let data = jsonLine.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data)
        else { return nil }
        self.init(foundation: parsed)
    }

    init(foundation value: Any) {
        switch value {
        case let dictionary as [String: Any]:
            self = .object(dictionary.mapValues(JSONValue.init(foundation:)))
        case let array as [Any]:
            self = .array(array.map(JSONValue.init(foundation:)))
        case let string as String:
            self = .string(string)
        case let number as NSNumber:
            // JSONSerialization returns booleans as NSNumber too
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.doubleValue)
            }
        default:
            self = .null
        }
    }

    subscript(key: String) -> JSONValue? {
        objectValue?[key]
    }

    var objectValue: [String: JSONValue]? {
        if case let .object(value) = self { value } else { nil }
    }

    var arrayValue: [JSONValue]? {
        if case let .array(value) = self { value } else { nil }
    }

    var stringValue: String? {
        if case let .string(value) = self { value } else { nil }
    }

    var doubleValue: Double? {
        if case let .number(value) = self { value } else { nil }
    }

    var boolValue: Bool? {
        if case let .bool(value) = self { value } else { nil }
    }
}
