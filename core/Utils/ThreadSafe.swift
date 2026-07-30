import Foundation

@propertyWrapper
public final class ThreadSafe<Value> {
    private var value: Value
    /// Recursive so `mutate` can safely coexist with reads via `wrappedValue` on the same thread.
    private let lock = NSRecursiveLock()

    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }

    public var wrappedValue: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }
    }

    /// In-place mutation under a single lock. Prefer updating the `inout` parameter, not `wrappedValue`.
    public func mutate(_ body: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&value)
    }
}
