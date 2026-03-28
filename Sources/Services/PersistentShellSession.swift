import Foundation

struct ShellCommandResult {
    let output: String
    let exitCode: Int32
}

enum ShellSessionError: LocalizedError {
    case shellUnavailable
    case startupFailed
    case stdinUnavailable
    case commandFailed(code: Int32, output: String)
    case executionTimeout(seconds: Int)

    var errorDescription: String? {
        switch self {
        case .shellUnavailable:
            return "Unable to start shell session."
        case .startupFailed:
            return "Shell session failed to start."
        case .stdinUnavailable:
            return "Shell session input stream is unavailable."
        case .commandFailed(let code, let output):
            let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return String(format: "Command failed with exit code %d.", Int(code))
            }
            return String(format: "Command failed with exit code %d: %@", Int(code), detail)
        case .executionTimeout(let seconds):
            return String(format: "Command timed out after %d seconds.", seconds)
        }
    }
}

actor PersistentShellSession {
    static let shared = PersistentShellSession()

    private let shellPath = "/bin/zsh"

    private var process: Process?
    private var inputHandle: FileHandle?
    private var outputReadTask: Task<Void, Never>?
    private var activeCommand: ActiveCommand?

    private init() {}

    deinit {
        outputReadTask?.cancel()
        process?.terminate()
    }

    func execute(command: String, timeoutSeconds: Int = 45) async throws -> ShellCommandResult {
        ClipFlowLogger.debug("[Shell] Starting command execution (timeout=\(timeoutSeconds)s)")
        try await ensureSessionStarted()

        guard let inputHandle else {
            ClipFlowLogger.error("[Shell] stdin unavailable")
            throw ShellSessionError.stdinUnavailable
        }

        let marker = "__CLIPFLOW_CMD_END__" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let wrappedCommand = "{ \(command); } </dev/null\nprintf '\(marker):%d\\n' $?\n"
        ClipFlowLogger.debug("[Shell] Command wrapped with marker: \(marker)")

        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task { [weak self] in
                let warningSeconds = min(5, max(1, timeoutSeconds / 3))
                try? await Task.sleep(nanoseconds: UInt64(warningSeconds) * 1_000_000_000)
                await self?.logCommandStillRunning(
                    marker: marker,
                    elapsedSeconds: warningSeconds,
                    timeoutSeconds: timeoutSeconds
                )
                try? await Task.sleep(nanoseconds: UInt64(max(0, timeoutSeconds - warningSeconds)) * 1_000_000_000)
                await self?.timeoutActiveCommand(marker: marker, timeoutSeconds: timeoutSeconds)
            }

            self.activeCommand = ActiveCommand(
                marker: marker,
                output: "",
                timeoutTask: timeoutTask,
                continuation: continuation
            )

            do {
                guard let data = wrappedCommand.data(using: .utf8) else {
                    throw ShellSessionError.commandFailed(code: -1, output: "Invalid command encoding")
                }
                try inputHandle.write(contentsOf: data)
                ClipFlowLogger.debug("[Shell] Command bytes written: \(data.count)")
            } catch {
                timeoutTask.cancel()
                self.activeCommand = nil
                continuation.resume(throwing: error)
            }
        }
    }

    func terminateSession() {
        activeCommand?.timeoutTask.cancel()
        activeCommand = nil
        outputReadTask?.cancel()
        outputReadTask = nil
        process?.terminate()
        process = nil
        inputHandle = nil
    }

    private func ensureSessionStarted() async throws {
        if let process, process.isRunning {
            ClipFlowLogger.debug("[Shell] Reusing existing shell session")
            return
        }

        ClipFlowLogger.debug("[Shell] Starting new shell session...")
        outputReadTask?.cancel()
        outputReadTask = nil
        process = nil
        inputHandle = nil

        let commandProcess = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()

        commandProcess.executableURL = URL(fileURLWithPath: shellPath)
        commandProcess.arguments = ["-l"]
        commandProcess.standardInput = inputPipe
        commandProcess.standardOutput = outputPipe
        commandProcess.standardError = outputPipe

        do {
            try commandProcess.run()
        } catch {
            ClipFlowLogger.error("[Shell] Failed to start process: \(error)")
            throw ShellSessionError.shellUnavailable
        }

        process = commandProcess
        inputHandle = inputPipe.fileHandleForWriting

        outputReadTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await line in outputPipe.fileHandleForReading.bytes.lines {
                    await self.handleOutputLine(line)
                }
                await self.handleSessionExit()
            } catch {
                await self.handleSessionExit()
            }
        }

        try await Task.sleep(nanoseconds: 120_000_000)
        guard commandProcess.isRunning else {
            ClipFlowLogger.error("[Shell] Shell process not running after 120ms startup delay")
            throw ShellSessionError.startupFailed
        }
        ClipFlowLogger.debug("[Shell] Shell session started successfully")
    }

    private func handleOutputLine(_ line: String) {
        guard var activeCommand else {
            return
        }

        ClipFlowLogger.debug("[Shell] Output line: \(line.prefix(300))")

        let markerPrefix = activeCommand.marker + ":"
        if line.hasPrefix(markerPrefix) {
            let codeText = String(line.dropFirst(markerPrefix.count))
            let exitCode = Int32(codeText) ?? -1
            let output = activeCommand.output.trimmingCharacters(in: .whitespacesAndNewlines)

            ClipFlowLogger.debug("[Shell] Marker detected, exitCode=\(exitCode), outputLen=\(output.count)")
            activeCommand.timeoutTask.cancel()
            self.activeCommand = nil

            if exitCode == 0 {
                ClipFlowLogger.debug("[Shell] Command succeeded")
                activeCommand.continuation.resume(returning: ShellCommandResult(output: output, exitCode: exitCode))
            } else {
                ClipFlowLogger.error("[Shell] Command failed with exit code \(exitCode), output: \(output.prefix(200))")
                activeCommand.continuation.resume(throwing: ShellSessionError.commandFailed(code: exitCode, output: output))
            }
            return
        }

        activeCommand.output += line + "\n"
        self.activeCommand = activeCommand
    }

    private func handleSessionExit() {
        ClipFlowLogger.warning("[Shell] Shell session exited unexpectedly")
        process = nil
        inputHandle = nil
        outputReadTask = nil

        guard let activeCommand else { return }
        activeCommand.timeoutTask.cancel()
        self.activeCommand = nil
        ClipFlowLogger.error("[Shell] Resuming with shellUnavailable error (had active command)")
        activeCommand.continuation.resume(throwing: ShellSessionError.shellUnavailable)
    }

    private func finishActiveCommand(marker: String, result: Result<ShellCommandResult, Error>) {
        guard let activeCommand, activeCommand.marker == marker else {
            return
        }

        activeCommand.timeoutTask.cancel()
        self.activeCommand = nil

        switch result {
        case .success(let value):
            ClipFlowLogger.debug("[Shell] finishActiveCommand: success")
            activeCommand.continuation.resume(returning: value)
        case .failure(let error):
            ClipFlowLogger.warning("[Shell] finishActiveCommand: failure - \(error)")
            activeCommand.continuation.resume(throwing: error)
            terminateSession()
        }
    }

    private func timeoutActiveCommand(marker: String, timeoutSeconds: Int) {
        guard let activeCommand, activeCommand.marker == marker else {
            return
        }

        let output = activeCommand.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = String(output.suffix(1000))

        if preview.isEmpty {
            ClipFlowLogger.error("[Shell] Command timed out after \(timeoutSeconds)s with no output")
        } else {
            ClipFlowLogger.error("[Shell] Command timed out after \(timeoutSeconds)s, last output: \(preview)")
        }

        let error: Error
        if preview.isEmpty {
            error = ShellSessionError.executionTimeout(seconds: timeoutSeconds)
        } else {
            error = ShellSessionError.commandFailed(
                code: 124,
                output: "Timed out after \(timeoutSeconds)s. Last output:\n\(preview)"
            )
        }

        finishActiveCommand(marker: marker, result: .failure(error))
    }

    private func logCommandStillRunning(marker: String, elapsedSeconds: Int, timeoutSeconds: Int) {
        guard let activeCommand, activeCommand.marker == marker else {
            return
        }

        let outputLength = activeCommand.output.count
        let isRunning = process?.isRunning ?? false
        ClipFlowLogger.warning(
            "[Shell] Command still running after \(elapsedSeconds)s/\(timeoutSeconds)s (processRunning=\(isRunning), outputLen=\(outputLength))"
        )
    }
}

private struct ActiveCommand {
    let marker: String
    var output: String
    let timeoutTask: Task<Void, Never>
    let continuation: CheckedContinuation<ShellCommandResult, Error>
}
