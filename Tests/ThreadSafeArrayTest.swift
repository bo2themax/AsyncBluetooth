//
//  ThreadSafeArrayTest.swift
//  AsyncBluetooth
//
//  Created by luca on 20.08.2025.
//

import Testing
@testable import AsyncBluetooth

@Test
func orderTest() async throws {
    let array: ThreadSafeArray<Int> = []
    let executor = SerialExecutor()
    for i in 1...1000 {
        executor.enqueue {
            await array.append(i)
        }
    }

    try await Task.sleep(nanoseconds: UInt64(1e6))
    try await #require(array.array == Array(1...1000))
}
