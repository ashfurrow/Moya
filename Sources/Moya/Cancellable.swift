/// Protocol to define the opaque type returned from a request.
public protocol Cancellable {

    /// A Boolean value stating whether a request is cancelled.
    var isCancelled: Bool { get }

    /// Cancels the represented request.
    func cancel()
}

internal class CancellableWrapper: Cancellable {
    internal var innerCancellable: any Cancellable = SimpleCancellable()

    var isCancelled: Bool { innerCancellable.isCancelled }

    internal func cancel() {
        innerCancellable.cancel()
    }
}

internal class SimpleCancellable: Cancellable {
    var isCancelled = false
    func cancel() {
        isCancelled = true
    }
}
