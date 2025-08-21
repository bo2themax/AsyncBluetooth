//
//  ATTRequest.swift
//  AsyncBluetooth
//
//  Created by luca on 19.08.2025.
//

@preconcurrency import CoreBluetooth
import Foundation

public final class ATTRequest: Sendable {
    let cbRequest: CBATTRequest
    /// The remote central device that originated the request.
    ///
    /// [Detail](https://developer.apple.com/documentation/corebluetooth/cbattrequest/central)
    public var central: Central {
        Central(cbCentra: cbRequest.central)
    }

    /// The characteristic to read or write the value of.
    ///
    /// [Detail](https://developer.apple.com/documentation/corebluetooth/cbattrequest/characteristic)
    public var characteristic: Characteristic { Characteristic(cbRequest.characteristic) }

    /// The zero-based index of the first byte for the read or write request.
    ///
    /// [Detail](https://developer.apple.com/documentation/corebluetooth/cbattrequest/offset)
    public var offset: Int { cbRequest.offset }

    /// The data that the central reads from or writes to the peripheral.
    ///
    /// [Detail](https://developer.apple.com/documentation/corebluetooth/cbattrequest/value)
    public var value: Data? {
        get { cbRequest.value }
        set { cbRequest.value = newValue }
    }

    init(cbRequest: CBATTRequest) {
        self.cbRequest = cbRequest
    }
}
