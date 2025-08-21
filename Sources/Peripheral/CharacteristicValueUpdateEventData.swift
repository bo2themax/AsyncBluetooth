// Copyright (c) 2024 Manuel Fernandez. All rights reserved.

import Foundation

public struct CharacteristicValueUpdateEventData {
    /// The characteristic whose value was updated.
    public let characteristic: Characteristic
    /// The value the characteristic changed to. We store it separately from the characteristic
    /// to avoid data races, given that the underlying CBCharacteristic's value might change
    /// before clients receive the publisher's value.
    public var value: Data? {
        try? valueResult.get()
    }

    /**
     A `Result` representing the outcome of reading the characteristic's value at the time of the update.
     If the update was successful, contains the value as `Data?`.
     If an error occurred during the update (such as in `peripheral(_:didUpdateValueFor:error:)`), contains the error.
     This is stored separately from the characteristic to avoid data races, ensuring clients access the correct value or error as it existed at the update event.
     */
    public let valueResult: Result<Data?, Error>

    init(characteristic: Characteristic, error: Error?) {
        self.characteristic = characteristic
        if let error {
            self.valueResult = .failure(error)
        } else {
            self.valueResult = .success(characteristic.value)
        }
    }
}
