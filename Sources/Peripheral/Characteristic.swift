//  Copyright (c) 2021 Manuel Fernandez-Peix Perez. All rights reserved.

import Foundation
@preconcurrency import CoreBluetooth

public protocol CoreBluetoothCharacteristic: Sendable, CustomStringConvertible {
    associatedtype CharacteristicType: CBCharacteristic
    var cbCharacteristic: CharacteristicType { get }
}

extension CoreBluetoothCharacteristic {
    public var description: String { cbCharacteristic.description }

    /// The Bluetooth-specific UUID of the characteristic.
    public var uuid: CBUUID {
        self.cbCharacteristic.uuid
    }

    public var properties: CBCharacteristicProperties {
        self.cbCharacteristic.properties
    }

    /// The latest value read for this characteristic.
    public var value: Data? {
        self.cbCharacteristic.value
    }

    /// A list of the descriptors discovered in this characteristic.
    public var descriptors: [Descriptor]? {
        self.cbCharacteristic.descriptors?.map { Descriptor($0) }
    }

    /// A Boolean value that indicates whether the characteristic is currently notifying a subscribed central
    /// of its value.
    public var isNotifying: Bool {
        self.cbCharacteristic.isNotifying
    }
}

/// A characteristic of a remote peripheral’s service.
/// - This class acts as a wrapper around `CBCharacteristic`.
public struct Characteristic: CoreBluetoothCharacteristic {
    public let cbCharacteristic: CBCharacteristic
    
    public init(_ cbCharacteristic: CBCharacteristic) {
        self.cbCharacteristic = cbCharacteristic
    }
}

/// A characteristic of a remote peripheral’s service.
/// - This class acts as a wrapper around `CBCharacteristic`.
public final class MutableCharacteristic: CoreBluetoothCharacteristic {
    public let cbCharacteristic: CBMutableCharacteristic
    var permissions: CBAttributePermissions {
        get { cbCharacteristic.permissions }
        set { cbCharacteristic.permissions = newValue }
    }
    var subscribedCentrals: [Central]? { cbCharacteristic.subscribedCentrals?.map({ Central(cbCentra: $0) }) }

    var properties: CBCharacteristicProperties {
        get { cbCharacteristic.properties }
        set { cbCharacteristic.properties = newValue }
    }

    var value: Data? {
        get { cbCharacteristic.value }
        set { cbCharacteristic.value = newValue }
    }

    var descriptors: [Descriptor]? {
        get { cbCharacteristic.descriptors?.map(Descriptor.init(_:)) }
        set { cbCharacteristic.descriptors = newValue?.map(\.cbDescriptor) }
    }

    /// A characteristic of a local peripheral’s service.
    /// - Parameters:
    ///   - uuid: The Bluetooth UUID of the characteristic.
    ///   - properties: The properties of the characteristic.
    ///   - value: The characteristic value to be cached. If <i>nil</i>, the value will be dynamic and requested on-demand.
    ///   - permissions: The permissions of the characteristic value.
    public init(type uuid: UUID, properties: CBCharacteristicProperties, value: Data?, permissions: CBAttributePermissions) {
        self.cbCharacteristic = CBMutableCharacteristic(type: CBUUID(nsuuid: uuid), properties: properties, value: value, permissions: permissions)
    }

    public init?(_ cbCharacteristic: CBCharacteristic) {
        guard let mutable = cbCharacteristic as? CBMutableCharacteristic else {
            return nil
        }
        self.cbCharacteristic = mutable
    }
}
