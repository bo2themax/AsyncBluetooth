//  Copyright (c) 2021 Manuel Fernandez-Peix Perez. All rights reserved.

import Combine
import CoreBluetooth
import Foundation

/// Contains the objects necessary to track a Central Manager's commands.
@available(watchOS, unavailable)
@available(visionOS, unavailable)
@available(tvOS, unavailable)
actor PeripheralManagerContext {
    nonisolated let eventSubject = PassthroughSubject<InternalPeripheralManagerEvent, Never>()

    // isolated inside the actor with a noisolated annotation for accessing publisher
    private nonisolated let subscribedCentralsSubject = CurrentValueSubject<[Central], Never>([])

    var subscribedCentrals: [Central] {
        subscribedCentralsSubject.value
    }

    nonisolated var subscribedCentralsPublisher: AnyPublisher<[Central], Never> {
        subscribedCentralsSubject.eraseToAnyPublisher()
    }

    private(set) lazy var waitUntilReadyExecutor = {
        let executor = AsyncSerialExecutor<Void>()
        flushableExecutors.append(executor)
        return executor
    }()

    private(set) lazy var startAdvertisingExecutor = {
        let executor = AsyncSerialExecutor<Void>()
        flushableExecutors.append(executor)
        return executor
    }()

    private(set) lazy var addServiceExecutor = {
        let executor = AsyncExecutorMap<String, Void>()
        flushableExecutors.append(executor)
        return executor
    }()

    private(set) lazy var updateValueWaitingExecutor = {
        let executor = AsyncSerialExecutor<Void>()
        flushableExecutors.append(executor)
        return executor
    }()

    private(set) lazy var publishChanelExecutor = {
        let executor = AsyncSerialExecutor<Void>()
        flushableExecutors.append(executor)
        return executor
    }()

    private(set) lazy var unpublishChanelExecutor = {
        let executor = AsyncSerialExecutor<Void>()
        flushableExecutors.append(executor)
        return executor
    }()

    private var flushableExecutors: ThreadSafeArray<FlushableExecutor> = []

    func flush(error: Error) async {
        for await flushableExecutor in flushableExecutors {
            await flushableExecutor.flush(error: error)
        }
    }

    func updateSubscribedCentrals(_ newValue: [Central]) {
        subscribedCentralsSubject.value = newValue
    }
}
