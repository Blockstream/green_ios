import Foundation
import core
import gdk

actor BCURProvider {
    private var parts = Set<String>()
    private var continuation: CheckedContinuation<String, Error>?

    func requestData(_ info: gdk.ResolveCodeAuthData) async throws -> String {
        continuation?.resume(throwing: CancellationError())
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            self.continuation = continuation
        }
    }

    func provide(part: String) {
        guard let continuation = self.continuation else { return }
        guard !parts.contains(part) else { return }
        parts.insert(part)
        continuation.resume(returning: part)
        self.continuation = nil
    }

    func reset() {
        continuation?.resume(throwing: CancellationError())
        continuation = nil
        parts.removeAll()
    }
}
