import AppKit
import SwiftUI

struct ProblemView: View {
    let problem: Problem

    var body: some View {
        let text = ProblemText.make(problem)
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(text.title)
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            Text(text.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let command = text.command {
                CommandRow(command: command)
            }
            if let link = text.link {
                Link(link.title, destination: link.url)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("problemView")
    }
}

struct ProblemBanner: View {
    let problem: Problem

    var body: some View {
        let text = ProblemText.make(problem)
        VStack(alignment: .leading, spacing: 6) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(text.title)
                        .fontWeight(.medium)
                    Text(text.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .font(.callout)
            if let command = text.command {
                CommandRow(command: command)
            }
            if let link = text.link {
                Link(link.title, destination: link.url)
                    .font(.callout)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("problemBanner")
    }
}

struct CommandRow: View {
    let command: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 6) {
            Text(command)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .lineLimit(1)
                // Truncating would hide part of the command, so shrink it instead
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Button(copied ? "Copied" : "Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                copied = true
            }
            .controlSize(.small)
            .accessibilityLabel(copied ? "Copied command" : "Copy command")
            .accessibilityIdentifier("copyCommandButton")
        }
    }
}

#if DEBUG
    #Preview("Problem") {
        PopoverContent(state: .problem(.noSubscriptionUsage), isRefreshing: false, now: PreviewData.now)
    }

    #Preview("Banner") {
        PopoverContent(state: .usage(PreviewData.normal, problem: .timedOut), isRefreshing: false, now: PreviewData.now)
    }
#endif
