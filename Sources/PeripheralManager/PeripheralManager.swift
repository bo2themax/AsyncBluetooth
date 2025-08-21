//  Copyright (c) 2021 Manuel Fernandez-Peix Perez. All rights reserved.

import Combine
@preconcurrency import CoreBluetooth
import Foundation
import os.log

/// An object that manages and advertises peripheral services exposed by this app using concurrency.
@available(watchOS, unavailable)
@available(visionOS, unavailable)
@available(tvOS, unavailable)
public final class PeripheralManager: Sendable {
    private typealias Utils = CentralManagerUtils

    fileprivate class DelegateWrapper: NSObject {
        private let context: PeripheralManagerContext

        init(context: PeripheralManagerContext) {
            self.context = context
        }
    }

    private static var logger: Logger {
        Logging.logger(for: "peripheralManager")
    }

    public var bluetoothState: CBManagerState {
        cbPeripheralManager.state
    }

    public var isAdvertising: Bool {
        cbPeripheralManager.isAdvertising
    }

    public var subscribedCentrals: [Central] {
        get async {
            await context.subscribedCentrals
        }
    }

    public var subscribedCentralsPublisher: AnyPublisher<[Central], Never> {
        context.subscribedCentralsPublisher
    }

    public var eventPublisher: AnyPublisher<PeripheralManagerEvent, Never> {
        context.eventSubject
            .compactMap { [weak self] in
                self.flatMap($0.toPublicEvent(manager:))
            }
            .eraseToAnyPublisher()
    }

    private let cbPeripheralManager: CBPeripheralManager
    private let context: PeripheralManagerContext
    private let cbPeripheralManagerDelegate: CBPeripheralManagerDelegate

    // MARK: Constructors

    /// Initializes the peripheral manager with dispatch queue, and initialization options.
    /// - Parameters:
    ///   - dispatchQueue: The dispatch queue for dispatching the peripheral role events. If the value is nil, the peripheral manager dispatches peripheral role events using the main queue.
    ///   - options: An optional dictionary containing initialization options for a peripheral manager. For available options, see [Peripheral Manager Initialization Options](https://developer.apple.com/documentation/corebluetooth/peripheral-manager-initialization-options).
    public init(dispatchQueue: DispatchQueue? = nil, options: [String: Any]? = nil) {
        self.context = PeripheralManagerContext()
        self.cbPeripheralManagerDelegate = DelegateWrapper(context: context)
        self.cbPeripheralManager = CBPeripheralManager(delegate: cbPeripheralManagerDelegate, queue: dispatchQueue, options: options)
    }

    // MARK: Public

    /// Waits until Bluetooth is ready. If the Bluetooth state is unknown or resetting, it
    /// will wait until a `peripheralManagerDidUpdateState` message is received. If Bluetooth is powered off,
    /// unsupported or unauthorized, an error will be thrown. Otherwise we'll continue.
    public func waitUntilReady() async throws {
        guard let isBluetoothReadyResult = Utils.isBluetoothReady(bluetoothState) else {
            Self.logger.info("Waiting for bluetooth to be ready...")

            try await context.waitUntilReadyExecutor.enqueue { [weak self] in
                // Note we need to check again here in case the Bluetooth state was updated after we last
                // checked but before the work was enqueued. Otherwise we could wait indefinitely.
                guard let self = self, let isBluetoothReadyResult = Utils.isBluetoothReady(self.cbPeripheralManager.state) else {
                    return
                }
                Task {
                    await self.context.waitUntilReadyExecutor.flush(isBluetoothReadyResult)
                }
            }
            return
        }

        switch isBluetoothReadyResult {
        case .success:
            return
        case let .failure(error):
            throw error
        }
    }

    /**
     Adds a service to the local GATT database.

     - Parameter service: The CBMutableService to add to the peripheral manager.

     [Official Documentation](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/add(_:))
     */
    public func add(_ service: MutableService) async throws {
        guard await !context.addServiceExecutor.hasWorkForKey(service.uuid.uuidString) else {
            Self.logger.error("Unable to add \(service), because an attempt is already in progress")
            throw BluetoothError.serviceAdditionInProgress
        }

        try await context.addServiceExecutor.enqueue(withKey: service.uuid.uuidString) { [weak self] in
            guard let self else {
                return
            }
            Self.logger.info("Adding \(service)")
            self.cbPeripheralManager.add(service.cbService)
        }
    }

    /**
     Removes a specified published service from the local GATT database.

     - Parameter service: The service you want to remove.

     [Official Documentation](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/remove(_:))
     */
    public func remove(_ service: MutableService) {
        cbPeripheralManager.remove(service.cbService)
    }

    /**
     Removes all published services from the local GATT database.

     [Official Documentation](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/removeallservices())
     */
    public func removeAllServices() {
        cbPeripheralManager.removeAllServices()
    }

    /**
     Advertises peripheral manager data.

     - Parameter localName: The local name of a peripheral.
     - Parameter serviceUUIDs: An array of service UUIDs.

     [Official Documentation](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/startadvertising(_:))
     */
    public func startAdvertising(localName: String? = nil, serviceUUIDs: [UUID]? = nil) async throws {
        guard await !context.startAdvertisingExecutor.hasWork else {
            Self.logger.error("Unable to start advertising, because an advertising attempt is already in progress")
            throw BluetoothError.advertisingInProgress
        }

        try await context.startAdvertisingExecutor.enqueue { [weak self] in
            guard let self else {
                return
            }
            Self.logger.info("Advertising localName: \(localName ?? "nil"), service ids: \(serviceUUIDs ?? [])")
            self.cbPeripheralManager.startAdvertising([
                CBAdvertisementDataLocalNameKey: localName as Any,
                CBAdvertisementDataServiceUUIDsKey: serviceUUIDs?.map(CBUUID.init(nsuuid:)) as Any,
            ])
        }
    }

    /**
     Stops advertising peripheral data.

     [Official Documentation](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/stopadvertising/)
     */
    public func stopAdvertising() async {
        Self.logger.info("Stopping advertising...")
        await context.startAdvertisingExecutor.flush(error: BluetoothError.operationCancelled)
        cbPeripheralManager.stopAdvertising()
    }

    /// Cancels all pending operations, stops scanning and awaiting for any responses.
    /// - Note: Operation for Peripherals will not be cancelled. To do that, call `cancelAllOperations()` on the `Peripheral`.
    public func cancelAllOperations() async {
        if isAdvertising {
            await stopAdvertising()
        }
        await context.flush(error: BluetoothError.operationCancelled)
    }

    /**
     Returns a publisher that emits every read request (`ATTRequest`) received from the specified central.

     - Parameter central: The `Central` for which to observe incoming read requests.
     - Returns: An `AnyPublisher` that emits each `ATTRequest` as it is received. The publisher never fails.

     Use this method to reactively handle read requests from a connected central device. You are responsible for responding to these requests using the `respond(to:withResult:)` method. Only requests that match the specified central are emitted.
     */
    public func readRequest(for central: Central) -> AnyPublisher<ATTRequest, Never> {
        context.eventSubject
            .compactMap { [weak central] event -> ATTRequest? in
                if case let .didReceiveRead(request) = event, request.central.identifier == central?.cbCentral.identifier {
                    return ATTRequest(cbRequest: request)
                } else {
                    return nil
                }
            }
            .eraseToAnyPublisher()
    }

    /**
     Returns a publisher that emits write requests (`[ATTRequest]`) received from the specified central.

     - Parameter central: The `Central` for which to observe incoming read requests.
     - Returns: An `AnyPublisher` that emits `[ATTRequest]` as it is received. The publisher never fails.

     Use this method to reactively handle read requests from a connected central device. You are responsible for responding to these requests using the `respond(to:withResult:)` method. Only requests that match the specified central are emitted.
     */
    public func writeRequests(for central: Central) -> AnyPublisher<[ATTRequest], Never> {
        context.eventSubject
            .map { [weak central] event -> [ATTRequest] in
                if case let .didReceiveWrite(requests) = event {
                    return requests.filter({ $0.central.identifier == central?.identifier })
                        .map(ATTRequest.init(cbRequest:))
                } else {
                    return []
                }
            }
            .filter { !$0.isEmpty }
            .eraseToAnyPublisher()
    }

    /**
     Updates the value of a characteristic and notifies subscribed centrals.

     - Parameters:
       - value: The new characteristic value to be set.
       - characteristic: The characteristic to update.
       - onSubscribedCentrals: An optional array of centrals to notify.

     This method attempts to send the update to the subscribed central(s). If the transmit queue is full and the update cannot be sent, it waits for `peripheralManagerIsReady(toUpdateSubscribers:)` before retrying. To cancel the retry, wrap this call in a Task and cancel the Task as needed.

     [Official Documentation](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/updatevalue(_:for:onsubscribedcentrals:))
     */
    public func updateValue(_ value: Data, for characteristic: MutableCharacteristic, onSubscribedCentrals centrals: [Central]? = nil) async throws {
        try Task.checkCancellation()
        await preconditionValueLength(value, for: centrals ?? characteristic.subscribedCentrals ?? [])
        let sent = cbPeripheralManager.updateValue(value, for: characteristic.cbCharacteristic, onSubscribedCentrals: centrals?.map(\.cbCentral))
        guard !sent else {
            Self.logger.info("Sent data for \(characteristic) to \(centrals ?? [])...")
            return // success
        }
        Self.logger.error("Failed to send data for \(characteristic) to \(centrals ?? []), waiting for next round...")
        // underlying transmit queue is full
        try await context.updateValueWaitingExecutor.enqueue {
            // empty work, waiting for isReady to
        }
        Self.logger.info("Ready to send data for \(characteristic) to \(centrals ?? [])...")
        // send again if not cancelled
        try await updateValue(value, for: characteristic, onSubscribedCentrals: centrals)
    }

    private func preconditionValueLength(_ value: Data, for centrals: [Central]) async {
        guard let maxLength = centrals.map(\.cbCentral.maximumUpdateValueLength).min() else {
            return
        }
        precondition(value.count <= maxLength, "The length of the value parameter exceeds the length of the minimum `maximumUpdateValueLength` property of a subscribed centrals, the value may not be sent successfully")
    }

    /**
     Responds to a read request from a central.

     - Parameters:
       - request: The read request to respond to.
       - result: The result code to respond with.

     [Official Documentation](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/respond(to:withresult:))
     */
    public func respond(to request: ATTRequest, withResult result: CBATTError.Code) {
        cbPeripheralManager.respond(to: request.cbRequest, withResult: result)
    }

    /**
     Sets the desired connection latency for an existing connection to a central device.

     - Parameters:
     - latency: The desired connection latency. For a list of the possible connection latency values that you may set for the peripheral manager, see [CBPeripheralManagerConnectionLatency](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanagerconnectionlatency).
     - central: The central to which the peripheral manager is currently connected.

     [Official Documentation](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/setdesiredconnectionlatency(_:for:))
     */
    public func setDesiredConnectionLatency(
        _ latency: CBPeripheralManagerConnectionLatency,
        for central: CBCentral
    ) {
        cbPeripheralManager.setDesiredConnectionLatency(latency, for: central)
    }

    /**
     Opens an L2CAP channel to a central device.

     - Parameter encryptionRequired: A Boolean indicating whether encryption is required.

     [Official Documentation](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/publishl2capchannel(withencryption:))
     */
    public func publishL2CAPChannel(withEncryption encryptionRequired: Bool) async throws {
        guard await !context.publishChanelExecutor.hasWork else {
            Self.logger.error("Unable to publish L2CAP channel, because an attempt is already in progress")
            throw BluetoothError.channelPublishingInProgress
        }

        try await context.publishChanelExecutor.enqueue { [weak self] in
            guard let self else {
                return
            }
            Self.logger.info("Publishing L2CAP channel withEncryption: \(encryptionRequired)")
            self.cbPeripheralManager.publishL2CAPChannel(withEncryption: encryptionRequired)
        }
    }

    /**
     Unpublishes an L2CAP channel.

     - Parameter PSM: The Protocol/Service Multiplexer (PSM) identifying the channel to unpublish.

     [Official Documentation](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager/unpublishl2capchannel(_:))
     */
    public func unpublishL2CAPChannel(_ PSM: CBL2CAPPSM) async throws {
        guard await !context.unpublishChanelExecutor.hasWork else {
            Self.logger.error("Unable to publish L2CAP channel, because an attempt is already in progress")
            throw BluetoothError.channelUnpublishingInProgress
        }

        try await context.unpublishChanelExecutor.enqueue { [weak self] in
            guard let self else {
                return
            }
            Self.logger.info("Unpublishing L2CAP channel: \(PSM)")
            self.cbPeripheralManager.unpublishL2CAPChannel(PSM)
        }
    }
}

// MARK: CBPeripheralManagerDelegate

@available(watchOS, unavailable)
@available(visionOS, unavailable)
@available(tvOS, unavailable)
extension PeripheralManager.DelegateWrapper: CBPeripheralManagerDelegate {
    private typealias Utils = CentralManagerUtils

    private static var logger: Logger = PeripheralManager.logger

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        context.eventSubject.send(.didUpdateState(state: peripheral.state))

        Task {
            guard let isBluetoothReadyResult = Utils.isBluetoothReady(peripheral.state) else { return }
            await context.waitUntilReadyExecutor.flush(isBluetoothReadyResult)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        context.eventSubject.send(.willRestoreState(state: dict))
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        Self.logger.info("peripheralManagerDidStartAdvertising, error: \(error.flatMap(String.init(describing:)) ?? "nil")")
        context.eventSubject.send(.didStartAdvertising(error: error))
        Task {
            do {
                if let error {
                    try await context.startAdvertisingExecutor.setWorkCompletedWithResult(.failure(error))
                } else {
                    try await context.startAdvertisingExecutor.setWorkCompletedWithResult(.success(()))
                }
            } catch {
                Self.logger.info("Received peripheralManagerDidStartAdvertising without a continuation: \(error)")
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
        Self.logger.info("peripheralManager didAdd \(service), error: \(error.flatMap(String.init(describing:)) ?? "nil")")
        context.eventSubject.send(.didAddService(service, error: error))
        Task {
            do {
                let result = CallbackUtils.result(for: (), error: error)
                try await context.addServiceExecutor.setWorkCompletedForKey(service.uuid.uuidString, result: result)
            } catch {
                Self.logger.info("peripheralManager didAdd \(service) without a continuation, error: \(error)")
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        Self.logger.info("peripheralManager central \(central), didSubscribeTo \(characteristic)")
        context.eventSubject.send(.centralDidSubscribe(central, Characteristic: characteristic))
        Task {
            var existing = await context.subscribedCentrals
            if let idx = existing.firstIndex(where: { $0.identifier == central.identifier }) {
                existing[idx].isSubscribed.value = true
            } else {
                existing.append(.init(cbCentra: central))
            }
            await context.updateSubscribedCentrals(existing)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        Self.logger.info("peripheralManager central \(central), didUnsubscribeFrom \(characteristic)")
        context.eventSubject.send(.centralDidUnsubscribe(central, Characteristic: characteristic))
        Task {
            var existing = await context.subscribedCentrals
            if let idx = existing.firstIndex(where: { $0.identifier == central.identifier }) {
                existing[idx].isSubscribed.value = false
                existing.remove(at: idx)
            }
            await context.updateSubscribedCentrals(existing)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        Self.logger.info("peripheralManager didReceiveRead \(request)")
        context.eventSubject.send(.didReceiveRead(request))
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        Self.logger.info("peripheralManager didReceiveWrite \(requests)")
        context.eventSubject.send(.didReceiveWrite(requests))
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        Self.logger.info("peripheralManagerIsReady toUpdateSubscribers")
        context.eventSubject.send(.isReadyToUpdateSubscribers)
        Task {
            await context.updateValueWaitingExecutor.flush(.success(()))
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: (any Error)?) {
        Self.logger.info("peripheralManager didPublishL2CAPChannel \(PSM), error: \(error.flatMap(String.init(describing:)) ?? "nil")")
        context.eventSubject.send(.didPublishL2CAPChannel(PSM, error: error))
        Task {
            do {
                let result = CallbackUtils.result(for: (), error: error)
                try await context.publishChanelExecutor.setWorkCompletedWithResult(result)
            } catch {
                Self.logger.info("peripheralManager didPublishL2CAPChannel \(PSM) without a continuation, error: \(error)")
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didUnpublishL2CAPChannel PSM: CBL2CAPPSM, error: (any Error)?) {
        Self.logger.info("peripheralManager didUnpublishL2CAPChannel \(PSM), error: \(error.flatMap(String.init(describing:)) ?? "nil")")
        context.eventSubject.send(.didUnpublishL2CAPChannel(PSM, error: error))
        Task {
            do {
                let result = CallbackUtils.result(for: (), error: error)
                try await context.unpublishChanelExecutor.setWorkCompletedWithResult(result)
            } catch {
                Self.logger.info("peripheralManager didUnpublishL2CAPChannel \(PSM) without a continuation, error: \(error)")
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: (any Error)?) {
        Self.logger.info("peripheralManager didOpen \(channel), error: \(error.flatMap(String.init(describing:)) ?? "nil")")
        context.eventSubject.send(.didOpenL2CAPChannel(channel, error: error))
    }
}
