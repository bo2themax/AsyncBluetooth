# AsyncBluetooth
A small library that adds concurrency to CoreBluetooth APIs.

## Features
- Async/Await APIs
- Queueing of commands
- Data conversion to common types
- Thread safety
- Convenience APIs for reading/writing without needing to explicitly discover characteristics.
- Convenience API for waiting until Bluetooth is ready.

## Usage

### Scanning for a peripheral

Start scanning by calling the central manager's `scanForPeripherals` 
function. It returns an `AsyncStream` you can use to iterate over the 
discovered peripherals. Once you're satisfied with your scan, you can 
break from the loop and stop scanning.

```swift
let centralManager = CentralManager()

try await centralManager.waitUntilReady()

let scanDataStream = try await centralManager.scanForPeripherals(withServices: nil)
for await scanData in scanDataStream {
    // Check scan data...
}

await centralManager.stopScan()
```
### Connecting to a peripheral

Once you have your peripheral, you can use the central manager to connect 
to it. Note you must hold a reference to the Peripheral while it's 
connected.

```swift
try await centralManager.connect(peripheral, options: nil)
```

### Subscribe to central manager events

The central manager publishes several events. You can subscribe to them by using the `eventPublisher`.

```swift
centralManager.eventPublisher
    .sink {
        switch $0 {
        case .didConnectPeripheral(let peripheral):
            print("Connected to \(peripheral.identifier)")
        default:
            break
        }
    }
    .store(in: &cancellables)
```

See [CentralManagerEvent](Sources/CentralManager/CentralManagerEvent.swift) to see available events.


### Read value from characteristic

You can use convenience functions for reading characteristics. They will find the characteristic by using a `UUID`, and 
parse the data into the appropriate type.

```swift
let value: String? = try await peripheral.readValue(
    forCharacteristicWithUUID: UUID(uuidString: "")!,
    ofServiceWithUUID: UUID(uuidString: "")!
)

```

### Write value to characteristic

Similar to reading, we have convenience functions for writing to characteristics.

```swift
try await peripheral.writeValue(
    value,
    forCharacteristicWithUUID: UUID(uuidString: "")!,
    ofServiceWithUUID: UUID(uuidString: "")!
)

```

### Subscribe to a characteristic

To get notified when a characteristic's value is updated, we provide a publisher you can subscribe to:

```swift
let characteristicUUID = CBUUID()
peripheral.characteristicValueUpdatedPublisher
    .filter { $0.characteristic.uuid == characteristicUUID }
    .map { try? $0.parsedValue() as String? } // replace `String?` with your type
    .sink { value in
        print("Value updated to '\(value)'")
    }
    .store(in: &cancellables)
```

Remember that you should enable notifications on that characteristic to receive updated values.

```swift
try await peripheral.setNotifyValue(true, characteristicUUID, serviceUUID)
```

### Canceling operations

To cancel a specific operation, you can wrap your call in a `Task`:

```swift
let fetchTask = Task {
    do {
        return try await peripheral.readValue(
            forCharacteristicWithUUID: UUID(uuidString: "")!,
            ofServiceWithUUID: UUID(uuidString: "")!
        )
    } catch {
        return ""
    }
}

fetchTask.cancel()
```

There might also be cases were you want to stop awaiting for all responses. For example, when bluetooth has been powered off. This can be done like so:

```swift
centralManager.eventPublisher
    .sink {
        switch $0 {
        case .didUpdateState(let state):
            guard state == .poweredOff else {
                return
            }
            centralManager.cancelAllOperations()
            peripheral.cancelAllOperations()
        default:
            break
        }
    }
    .store(in: &cancellables)
```

### Advertising Peripherals

To advertise your device as a Bluetooth peripheral, use the `PeripheralManager`. Here’s a step-by-step example:

```swift
// 1. Wait until the PeripheralManager is ready
try await peripheralManager.waitUntilReady()

// 2. Remove any existing services if needed
peripheralManager.removeAllServices()

// 3. Define characteristics for communication
let centralToPeripheralCharacteristic = MutableCharacteristic(
    type: UUID(uuidString: "993F9F06-A952-4909-8BA8-72FDB46A8607")!,
    properties: [.write, .writeWithoutResponse],
    value: nil,
    permissions: [.writeable] // Central can write, peripheral can read
)

let peripheralToCentralCharacteristic = MutableCharacteristic(
    type: UUID(uuidString: "E88002B3-3A05-4F71-9332-CE59CF8DCDA6")!,
    properties: [.notify, .indicate],
    value: nil,
    permissions: [.readable] // Peripheral can notify, central can read
)

// 4. Create a service and add the characteristics
let service = MutableService(
    type: UUID(uuidString: "E88002B2-3A05-4F71-9332-CE59CF8DCDA6")!,
    primary: true
)
service.characteristics = [centralToPeripheralCharacteristic, peripheralToCentralCharacteristic]

// 5. Add the service to the PeripheralManager
try await peripheralManager.add(service)

// 6. Start advertising if not already advertising
guard !peripheralManager.isAdvertising else { return }
try await peripheralManager.startAdvertising(
    localName: "Cookbook",
    serviceUUIDs: [UUID(uuidString: "E88002B2-3A05-4F71-9332-CE59CF8DCDA6")!]
)

// 7. Track subscribed centrals for later use
subscribedCentrals = await peripheralManager.subscribedCentrals.filter { $0.isSubscribed.value }
centralObserver = peripheralManager.subscribedCentralsPublisher
    .sink { [weak self] newValue in
        self?.subscribedCentrals = newValue.filter { $0.isSubscribed.value }
    }
```

This example shows how to set up a peripheral, define its services and characteristics, start advertising, and monitor which centrals are subscribed.

For demo case, check out [AsyncBluetooth Cookbook](https://github.com/manolofdez/AsyncBluetoothCookbook).

### Logging

The library uses `os.log` to provide logging for several operations. These logs are enabled by default. If you wish to disable them, you can do:

```
AsyncBluetoothLogging.setEnabled(false)
```

## Examples

You can find practical, tasty recipes for how to use `AsyncBluetooth` in the 
[AsyncBluetooth Cookbook](https://github.com/manolofdez/AsyncBluetoothCookbook).

## Installation

### Swift Package Manager

This library can be installed using the Swift Package Manager by adding it 
to your Package Dependencies.

## Requirements

- iOS 14.0+
- MacOS 11.0+
- Swift 5
- Xcode 13.2.1+

## License

Licensed under MIT license.
