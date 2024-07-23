import Foundation
import CoreBluetooth
import AsyncBluetooth
import SwiftCBOR
import Combine
import Semaphore

public class BleJadeConnection: HWConnectionProtocol {

    public var peripheral: Peripheral
    public weak var centralManager: CentralManager?

    public static let SERVICE_UUID = UUID(uuidString: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")!
    public let WRITE_CHARACTERISTIC_UUID = UUID(uuidString: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")!
    public let CLIENT_CHARACTERISTIC_CONFIG = UUID(uuidString: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")!

    private var semaphore = AsyncSemaphore(value: 1)
    private var semaphoreQueue = AsyncSemaphore(value: 0)
    private var mtu = 128
    private var centralCancellables = Set<AnyCancellable>()
    private var characteristicCancellables = Set<AnyCancellable>()
    private var queue = [Data]()
    private var closed = true

    public init(peripheral: Peripheral, centralManager: CentralManager?) {
        self.peripheral = peripheral
        self.centralManager = centralManager
        self.listening()
    }
    
    public func listening() {
        centralManager?.eventPublisher
            .sink {
                switch $0 {
                case .didUpdateState(let state):
                    guard state == .poweredOff else {
                        return
                    }
                    Task { try await self.close() }
                case .didConnectPeripheral(let peripheral):
                    self.closed = false
                case .didDisconnectPeripheral(let peripheral, let isReconnecting, let error):
                    print("Disconnected to \(error?.localizedDescription)")
                    self.closed = true
                    Task { try await self.close() }
                default:
                    break
                }
            }
            .store(in: &centralCancellables)
    }

    public func open() async throws {
        semaphore = AsyncSemaphore(value: 1)
        semaphoreQueue = AsyncSemaphore(value: 0)
        try await centralManager?.connect(peripheral)
        mtu = peripheral.maximumWriteValueLength(for: .withResponse)
        print ("MTU \(mtu)")
        try await peripheral.setNotifyValue(false, forCharacteristicWithUUID: CLIENT_CHARACTERISTIC_CONFIG, ofServiceWithUUID: BleJadeConnection.SERVICE_UUID)
        try await peripheral.discoverServices(nil)
        for service in peripheral.discoveredServices ?? [] {
            try await peripheral.discoverCharacteristics(nil, for: service)
            service.discoveredCharacteristics!.forEach {
                print("\($0.uuid) \($0.properties) \($0.isNotifying)")
            }
        }
        try await setNotifyValue()
        var buffer = Data()
        peripheral.characteristicValueUpdatedPublisher
            // .map { print("Data '\($0.value)'"); return $0 }
            .filter { $0.uuid.uuidString == self.CLIENT_CHARACTERISTIC_CONFIG.uuidString }
            .map { try? $0.parsedValue() as Data? } // replace `String?` with your type
            .sink(receiveValue: { [self] value in
                buffer.append((value ?? Data())!)
                let decode = try? CBOR.decode([UInt8](buffer))
                if decode != nil {
                    self.queue.append(buffer)
                    semaphoreQueue.signal()
                    buffer = Data()
                }
            }).store(in: &characteristicCancellables)
    }

    func setNotifyValue() async throws {
        var attempts = 0
        repeat {
            do {
                try await peripheral.setNotifyValue(true, forCharacteristicWithUUID: CLIENT_CHARACTERISTIC_CONFIG, ofServiceWithUUID: BleJadeConnection.SERVICE_UUID)
                return
            } catch {
                attempts += 1
                try await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            }
        } while (attempts < 3)
        throw HWError.Abort("Failure on bluetooth device initialization")
    }

    public func read() async throws -> Data? {
        try await semaphoreQueue.waitUnlessCancelled()
        if queue.isEmpty {
            return nil
        }
        let msg = queue.removeFirst()
        return msg
    }

    public func write(_ data: Data) async throws {
        let chunks = data.chunked(into: 128)
        for chunk in chunks {
            try await peripheral.writeValue(chunk, forCharacteristicWithUUID: WRITE_CHARACTERISTIC_UUID, ofServiceWithUUID: BleJadeConnection.SERVICE_UUID, type: .withResponse)
        }
    }

    public func exchange(_ data: Data) async throws -> Data {
        try await semaphore.waitUnlessCancelled()
        if closed {
            throw HWError.InvalidResponse("Disconnected")
        }
#if DEBUG
        print(">= \(data.hex)")
#endif
        try await write(data)
        if let result = try await read() {
#if DEBUG
            print("<= \(result.hex)")
#endif
            semaphore.signal()
            return result
        }
        semaphore.signal()
        throw HWError.InvalidResponse("")
    }

    public func close() async throws {
        semaphore.signal()
        semaphoreQueue.signal()
        try? await peripheral.cancelAllOperations()
        try? await centralManager?.cancelAllOperations()
        try? await centralManager?.cancelPeripheralConnection(peripheral)
        characteristicCancellables.forEach { $0.cancel() }
    }
    
    deinit {
        centralCancellables.forEach { $0.cancel() }
    }
}
