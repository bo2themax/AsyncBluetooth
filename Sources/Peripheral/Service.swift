//  Copyright (c) 2021 Manuel Fernandez-Peix Perez. All rights reserved.

import Foundation
@preconcurrency import CoreBluetooth

/// A collection of data and associated behaviors that accomplish a function or feature of a device.
/// - This class acts as a wrapper around `CBService`.
public protocol CoreBluetoothService: Sendable, CustomStringConvertible {
    associatedtype ServiceType: CBService
    var cbService: ServiceType { get }
}

public extension CoreBluetoothService {
    var description: String {
        cbService.description
    }

    /// The Bluetooth-specific UUID of the service.
    var uuid: CBUUID {
        self.cbService.uuid
    }

    /// A Boolean value that indicates whether the type of service is primary or secondary. A primary service
    /// describes the primary function of a device. A secondary service describes a service that’s relevant only
    /// in the context of another service that references it.
    var isPrimary: Bool {
        self.cbService.isPrimary
    }
}
/// A collection of data and associated behaviors that accomplish a function or feature of a device.
/// - This class acts as a wrapper around `CBService`.
public struct Service: CoreBluetoothService {
    public let cbService: CBService

    /// A list of included services discovered in this service.
    public var discoveredIncludedServices: [Service]? {
        self.cbService.includedServices?.map { Service($0) }
    }
    
    /// A list of characteristics discovered in this service.
    public var discoveredCharacteristics: [Characteristic]? {
        self.cbService.characteristics?.map { Characteristic($0) }
    }
    
    public init(_ cbService: CBService) {
        self.cbService = cbService
    }
}

/// A collection of data and associated behaviors that accomplish a function or feature of a device.
/// - This class acts as a wrapper around `CBMutableService`.
public final class MutableService: CoreBluetoothService {
    public let cbService: CBMutableService

    /// A list of included services.
    public var includedServices: [Service]? {
        get { cbService.includedServices?.map { Service($0) } }
        set { cbService.includedServices = newValue?.map(\.cbService) }
    }

    /// A list of characteristics of a service.
    public var characteristics: [MutableCharacteristic]? {
        get { cbService.characteristics?.compactMap { MutableCharacteristic($0) } }
        set { cbService.characteristics = newValue?.map(\.cbCharacteristic) }
    }

    /// Creates a newly initialized mutable service specified by UUID and service type.
    public init(type uuid: UUID, primary isPrimary: Bool) {
        cbService = CBMutableService(type: CBUUID(nsuuid: uuid), primary: isPrimary)
    }
}
