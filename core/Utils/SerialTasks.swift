import Foundation

public actor SerialTasks<Success> {
    private var previousTask: Task<Success, Error>?

    public init(previousTask: Task<Success, Error>? = nil) {
        self.previousTask = previousTask
    }

    public func add(block: @Sendable @escaping () async throws -> Success) async throws -> Success {
        let task = Task { [previousTask] in
            let _ = await previousTask?.result
            return try await block()
        }
        previousTask = task
        return try await task.value
    }
}
