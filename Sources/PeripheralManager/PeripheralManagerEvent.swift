// Copyright (c) 2022 Manuel Fernandez. All rights reserved.

import Foundation
import CoreBluetooth

@available(watchOS, unavailable)
@available(visionOS, unavailable)
@available(tvOS, unavailable)
public enum PeripheralManagerEvent {
    case didUpdateState(state: CBManagerState, manager: PeripheralManager)
    case willRestoreState(state: [String: Any], manager: PeripheralManager)
    case didStartAdvertising(error: Error?, manager: PeripheralManager)
    case didAddService(_ service: CBService, error: Error?, manager: PeripheralManager)
    case centralDidSubscribe(_ central: CBCentral, Characteristic: CBCharacteristic, manager: PeripheralManager)
    case centralDidUnsubscribe(_ central: CBCentral, Characteristic: CBCharacteristic, manager: PeripheralManager)
    case didReceiveRead(_ request: [CBATTRequest], manager: PeripheralManager)
    case didReceiveWrite(_ request: [CBATTRequest], manager: PeripheralManager)
    case isReadyToUpdateSubscribers(manager: PeripheralManager)
    case didPublishL2CAPChannel(_ psm: CBL2CAPPSM, error: Error?, manager: PeripheralManager)
    case didUnpublishL2CAPChannel(_ psm: CBL2CAPPSM, error: Error?, manager: PeripheralManager)
    case didOpenL2CAPChannel(_ channel: CBL2CAPChannel?, error: Error?, manager: PeripheralManager)
}

@available(watchOS, unavailable)
@available(visionOS, unavailable)
@available(tvOS, unavailable)
enum InternalPeripheralManagerEvent {
    case didUpdateState(state: CBManagerState)
    case willRestoreState(state: [String: Any])
    case didStartAdvertising(error: Error?)
    case didAddService(_ service: CBService, error: Error?)
    case centralDidSubscribe(_ central: CBCentral, Characteristic: CBCharacteristic)
    case centralDidUnsubscribe(_ central: CBCentral, Characteristic: CBCharacteristic)
    case didReceiveRead(_ request: [CBATTRequest])
    case didReceiveWrite(_ request: [CBATTRequest])
    case isReadyToUpdateSubscribers
    case didPublishL2CAPChannel(_ psm: CBL2CAPPSM, error: Error?)
    case didUnpublishL2CAPChannel(_ psm: CBL2CAPPSM, error: Error?)
    case didOpenL2CAPChannel(_ channel: CBL2CAPChannel?, error: Error?)

    func toPublicEvent(manager: PeripheralManager) -> PeripheralManagerEvent {
        switch self {
        case .didUpdateState(let state):
            return .didUpdateState(state: state, manager: manager)
        case .willRestoreState(let state):
            return .willRestoreState(state: state, manager: manager)
        case .didStartAdvertising(let error):
            return .didStartAdvertising(error: error, manager: manager)
        case .didAddService(let service, let error):
            return .didAddService(service, error: error, manager: manager)
        case .centralDidSubscribe(let central, let characteristic):
            return .centralDidSubscribe(central, Characteristic: characteristic, manager: manager)
        case .centralDidUnsubscribe(let central, let characteristic):
            return .centralDidUnsubscribe(central, Characteristic: characteristic, manager: manager)
        case .didReceiveRead(let request):
            return .didReceiveRead(request, manager: manager)
        case .didReceiveWrite(let request):
            return .didReceiveWrite(request, manager: manager)
        case .isReadyToUpdateSubscribers:
            return .isReadyToUpdateSubscribers(manager: manager)
        case .didPublishL2CAPChannel(let psm, let error):
            return .didPublishL2CAPChannel(psm, error: error, manager: manager)
        case .didUnpublishL2CAPChannel(let psm, let error):
            return .didUnpublishL2CAPChannel(psm, error: error, manager: manager)
        case .didOpenL2CAPChannel(let channel, let error):
            return .didOpenL2CAPChannel(channel, error: error, manager: manager)
        }
    }
}
