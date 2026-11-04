import Foundation
import Synchronization

struct CommandSpec: Sendable, Equatable {
    var executable: URL
    var arguments: [String]
    var environment: [String: String]
    var currentDirectory: URL
    var timeout: Duration
}

struct CommandOutput: Sendable, Equatable {
    var exitCode: Int32
    var stdout: String
    var stderr: String
    var timedOut = false
    var duration: Duration = .zero

    var stdoutLines: [String] {
        stdout.components(separatedBy: "\n")
    }
}

enum CommandError: Error, Equatable {
    case notFound
    case launchFailed(String)
}

protocol CommandRunner: Sendable {
    func run(_ command: CommandSpec) async throws -> CommandOutput
}

struct ProcessCommandRunner: CommandRunner {
    var stdoutLimit = 1 << 20
    var stderrLimit = 64 << 10
    var killGrace: TimeInterval = 2

    func run(_ command: CommandSpec) async throws -> CommandOutput {
        let process = Process()
        process.executableURL = command.executable
        process.arguments = command.arguments
        process.environment = command.environment
        process.currentDirectoryURL = command.currentDirectory
        // Otherwise claude waits 3 s for input before carrying on
        process.standardInput = FileHandle.nullDevice

        // Both pipes are drained as data arrives, so a chatty process can't block on a full pipe
        let stdout = PipeCollector(limit: stdoutLimit, keep: .head)
        let stderr = PipeCollector(limit: stderrLimit, keep: .tail)
        process.standardOutput = stdout.pipe
        process.standardError = stderr.pipe

        let exit = ExitStatus()
        process.terminationHandler = { exit.finish($0.terminationStatus) }

        let clock = ContinuousClock()
        let start = clock.now
        do {
            try process.run()
        } catch {
            stdout.stop()
            stderr.stop()
            throw Self.launchError(error, path: command.executable.path)
        }
        let pid = process.processIdentifier

        let ending = await withTaskGroup(of: Ending.self) { group in
            group.addTask {
                await exit.wait()
                return .exited
            }
            group.addTask {
                do {
                    try await Task.sleep(for: command.timeout)
                    return .timedOut
                } catch {
                    return .cancelled
                }
            }
            let first = await group.next() ?? .exited
            if first != .exited {
                terminate(pid: pid, exit: exit)
            }
            group.cancelAll()
            return first
        }
        let status = await exit.wait()
        // Output can still be in the pipes when the exit notification arrives
        await stdout.waitForEnd(timeout: .seconds(1))
        await stderr.waitForEnd(timeout: .seconds(1))
        stdout.stop()
        stderr.stop()
        withExtendedLifetime(process) {}

        if ending == .cancelled {
            throw CancellationError()
        }
        return CommandOutput(
            exitCode: status,
            stdout: stdout.text,
            stderr: stderr.text,
            timedOut: ending == .timedOut,
            duration: clock.now - start,
        )
    }

    private enum Ending {
        case exited
        case timedOut
        case cancelled
    }

    private func terminate(pid: pid_t, exit: ExitStatus) {
        guard !exit.hasExited else { return }
        Self.send(SIGTERM, to: pid)
        DispatchQueue.global().asyncAfter(deadline: .now() + killGrace) {
            // Checked again so a pid reused after the process ended is never signalled
            if !exit.hasExited {
                Self.send(SIGKILL, to: pid)
            }
        }
    }

    // Process makes the child a process group leader, so signalling the group
    // also stops anything it started, like the claude a version manager's shim
    // runs as a child. The child alone if it somehow has no group of its own.
    private static func send(_ signal: Int32, to pid: pid_t) {
        if kill(-pid, signal) != 0 {
            kill(pid, signal)
        }
    }

    private static func launchError(_ error: Error, path: String) -> CommandError {
        FileManager.default.fileExists(atPath: path) ? .launchFailed(error.localizedDescription) : .notFound
    }
}

private final class ExitStatus: Sendable {
    private struct State {
        var status: Int32?
        var waiters: [CheckedContinuation<Int32, Never>] = []
    }

    private let state = Mutex(State())

    var hasExited: Bool {
        state.withLock { $0.status != nil }
    }

    func finish(_ status: Int32) {
        let waiters = state.withLock { state in
            state.status = status
            defer { state.waiters = [] }
            return state.waiters
        }
        for waiter in waiters {
            waiter.resume(returning: status)
        }
    }

    @discardableResult
    func wait() async -> Int32 {
        await withCheckedContinuation { continuation in
            let status = state.withLock { state -> Int32? in
                if let status = state.status { return status }
                state.waiters.append(continuation)
                return nil
            }
            if let status {
                continuation.resume(returning: status)
            }
        }
    }
}

private final class PipeCollector: Sendable {
    enum Keep {
        case head
        case tail
    }

    private struct State {
        var data = Data()
        var ended = false
    }

    let pipe = Pipe()
    private let limit: Int
    private let keep: Keep
    private let state = Mutex(State())

    init(limit: Int, keep: Keep) {
        self.limit = limit
        self.keep = keep
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard let self, !chunk.isEmpty else {
                handle.readabilityHandler = nil
                self?.state.withLock { $0.ended = true }
                return
            }
            append(chunk)
        }
    }

    var text: String {
        String(decoding: state.withLock { $0.data }, as: UTF8.self)
    }

    func waitForEnd(timeout: Duration) async {
        let deadline = ContinuousClock.now + timeout
        while !state.withLock({ $0.ended }), ContinuousClock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func stop() {
        pipe.fileHandleForReading.readabilityHandler = nil
    }

    private func append(_ chunk: Data) {
        state.withLock { state in
            if keep == .head, state.data.count >= limit { return }
            state.data.append(chunk)
            guard state.data.count > limit else { return }
            state.data = switch keep {
            case .head: Data(state.data.prefix(limit))
            case .tail: Data(state.data.suffix(limit))
            }
        }
    }
}
