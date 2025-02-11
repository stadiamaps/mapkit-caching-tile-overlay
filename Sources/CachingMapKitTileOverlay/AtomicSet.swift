import Foundation

class AtomicSet<Value: Hashable>: CustomDebugStringConvertible {
    private var storage = Set<Value>()

    private let queue = DispatchQueue(label: "com.donnywals.\(UUID().uuidString)",
                                      qos: .utility,
                                      autoreleaseFrequency: .inherit,
                                      target: .global())

    public init() {}

    public func contains(_ key: Value) -> Bool {
        queue.sync { self.storage.contains(key) }
    }

    @discardableResult
    public func insert(_ key: Value) -> (Bool, Value) {
        queue.sync { self.storage.insert(key) }
    }

    @discardableResult
    public func remove(_ key: Value) -> Value? {
        queue.sync { self.storage.remove(key) }
    }

    public var debugDescription: String {
        return storage.debugDescription
    }
}
