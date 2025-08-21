//
//  SerialExecutor.swift
//  AsyncBluetooth
//
//  Created by luca on 20.08.2025.
//

/// An executor that guarantees the async job order
final class SerialExecutor: Sendable {
    private let continuation: AsyncStream<() async -> Void>.Continuation

    init() {
        var c: AsyncStream<() async -> Void>.Continuation!
        let stream = AsyncStream<() async -> Void> { cont in
            c = cont
        }
        continuation = c

        // Single task consuming jobs in FIFO order
        Task {
            for await job in stream {
                await job()
            }
        }
    }

    func enqueue(_ job: @escaping () async -> Void) {
        continuation.yield(job)   // sync, ordered
    }
}
