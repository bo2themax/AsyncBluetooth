//  Copyright (c) 2021 Manuel Fernandez-Peix Perez. All rights reserved.

import CoreBluetooth
import Foundation

/// Represents a single value gathered when scanning for peripheral.
public struct ScanData: Sendable {
    public let peripheral: Peripheral
    /// A dictionary containing any advertisement and scan response data.
    public let advertisementData: [String: any Sendable]
    /// The current RSSI of the peripheral, in dBm. A value of 127 is reserved and indicates the RSSI
    /// was not available.
    public let rssi: NSNumber
}

public extension ScanData {
    /// The local name of a peripheral.
    var localName: String? {
        advertisementData[CBAdvertisementDataLocalNameKey] as? String
    }

    /// The transmit power of a peripheral.
    var txPower: NSNumber? {
        advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
    }

    var serviceUUIds: [CBUUID]? {
        advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
    }

    /// A dictionary that contains service-specific advertisement data.
    var serviceData: [CBUUID: Data]? {
        advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
    }

    /// The manufacturer data of a peripheral.
    var manufacturerData: Data? {
        advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
    }

    /// An array of UUIDs found in the overflow area of the advertisement data.
    var dataOverflowServiceUUIDs: [CBUUID]? {
        advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
    }

    /// A Boolean value that indicates whether the advertising event type is connectable.
    var isConnectable: Bool? {
        advertisementData[CBAdvertisementDataIsConnectable] as? Bool
    }

    /// An array of solicited service UUIDs.
    var solicitedServiceUUIDs: [CBUUID]? {
        advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
    }
}
