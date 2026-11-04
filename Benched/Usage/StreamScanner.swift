import Foundation

struct StreamScan: Sendable, Equatable {
    var claudeVersion: String?
    var apiKeySource: String?
    var report: JSONValue?
    // The human-readable report, used to classify failures, never for numbers
    var text: String?
}

// If the report moves, the classifier says Claude Code changed how it
// reports usage, and a new fixture shows where it went
enum StreamScanner {
    static func scan(_ lines: some Sequence<String>) -> StreamScan {
        var scan = StreamScan()
        var resultText: String?
        var assistantText: String?

        for line in lines {
            // Warnings sometimes land on stdout, and the last line can be cut off
            guard let message = JSONValue(jsonLine: line), message.objectValue != nil else { continue }

            switch message["type"]?.stringValue {
            case "system" where message["subtype"]?.stringValue == "init":
                scan.claudeVersion = message["claude_code_version"]?.stringValue ?? scan.claudeVersion
                scan.apiKeySource = message["apiKeySource"]?.stringValue ?? scan.apiKeySource
            case "assistant":
                if scan.report == nil, let report = message["usage_report"], report.objectValue != nil {
                    scan.report = report
                }
                assistantText = assistantText ?? contentText(of: message)
            case "result":
                resultText = message["result"]?.stringValue ?? resultText
            default:
                break
            }
        }

        scan.text = resultText ?? assistantText
        return scan
    }

    private static func contentText(of message: JSONValue) -> String? {
        let texts = message["message"]?["content"]?.arrayValue?.compactMap { $0["text"]?.stringValue } ?? []
        return texts.isEmpty ? nil : texts.joined(separator: "\n")
    }
}
