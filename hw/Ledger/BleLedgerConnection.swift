import Foundation
import CoreBluetooth
import AsyncBluetooth
import SwiftCBOR
import Combine
import greenaddress
import Semaphore

public class BleLedgerConnection: HWConnectionProtocol {

    public var peripheral: Peripheral
    public weak var centralManager: CentralManager?
    private static let TAG_APDU: UInt8 = 0x05
    public static let SERVICE_UUID = UUID(uuidString: "13D63400-2C97-0004-0000-4C6564676572")!
    public let WRITE_CHARACTERISTIC_UUID = UUID(uuidString: "13D63400-2C97-0004-0002-4C6564676572")!
    public let READ_CHARACTERISTIC_CONFIG = UUID(uuidString: "13D63400-2C97-0004-0001-4C6564676572")!

    public var connected = false
    private var MTU = 128
    private let semaphore = AsyncSemaphore(value: 1)
    private let semaphoreQueue = AsyncSemaphore(value: 0)
    private var cancellable: AnyCancellable?
    private var queue = [Data]()
    private let reqMtu = Data([0x08, 0x00, 0x00, 0x00, 0x00])

    public enum LedgerError: Error {
        case InvalidParameter
        case IOError
    }

    // Status codes
    public enum SWCode: UInt16 {
        case SW_OK = 0x9000
        case SW_INS_NOT_SUPPORTED = 0x6D00
        case SW_WRONG_P1_P2 = 0x6B00
        case SW_INCORRECT_P1_P2 = 0x6A86
        case SW_RECONNECT = 0x6FAA
        case SW_INVALID_STATUS = 0x6700
        case SW_REJECTED = 0x6985
        case SW_INVALID_PKG = 0x6982
        case SW_ABORT = 0x0000
    }

    // Status error
    public class SWError: Error {
        public let code: SWCode
        public init(_ code: SWCode) {
            self.code = code
        }
        public func description() -> String? {
            switch code {
            case .SW_OK:
                return nil
            case .SW_INS_NOT_SUPPORTED:
                return "Command not supported"
            case .SW_WRONG_P1_P2:
                return "Wrong package"
            case .SW_INCORRECT_P1_P2:
                return "Incorrect package"
            case .SW_RECONNECT:
                return "Reconnection required"
            case .SW_INVALID_STATUS:
                return "Invalid status"
            case .SW_REJECTED:
                return "Transaction was rejected by user"
            case .SW_INVALID_PKG:
                return "Invalid package"
            case .SW_ABORT:
                return "Aborted operation"
            }
        }
    }

    public init(peripheral: Peripheral, centralManager: CentralManager?) {
        self.peripheral = peripheral
        self.centralManager = centralManager
    }

    public func open() async throws {
        try await centralManager?.connect(peripheral)
        let mtu = peripheral.maximumWriteValueLength(for: .withResponse)
        try await peripheral.discoverServices(nil)
        for service in peripheral.discoveredServices ?? [] {
            try await peripheral.discoverCharacteristics(nil, for: service)
            service.discoveredCharacteristics!.forEach {
                print("characteristic \($0.uuid) \($0.properties) \($0.isNotifying)")
            }
        }
        try await peripheral.setNotifyValue(true, forCharacteristicWithUUID: READ_CHARACTERISTIC_CONFIG, ofServiceWithUUID: BleLedgerConnection.SERVICE_UUID)

        cancellable = peripheral.characteristicValueUpdatedPublisher
            .filter { $0.uuid.uuidString == self.READ_CHARACTERISTIC_CONFIG.uuidString }
            .map { try? $0.parsedValue() as Data? } // replace `String?` with your type
            .sink(receiveValue: { [self] value in
                self.queue.append(value ?? Data())
                semaphoreQueue.signal()
                semaphore.signal()
            })

        let resMtu = try await exchange(reqMtu)
        MTU = Int(resMtu[0]) - 3
        print ("MTU \(MTU)")
        connected = true
    }

    public func read() async throws -> Data? {
        await semaphoreQueue.wait()
        if queue.isEmpty {
            return nil
        }
        let msg = queue.removeFirst()
        return msg
    }

    public func write(_ data: Data) async throws {
        let chunks = data.chunked(into: MTU)
        for chunk in chunks {
            try await peripheral.writeValue(chunk, forCharacteristicWithUUID: WRITE_CHARACTERISTIC_UUID, ofServiceWithUUID: BleLedgerConnection.SERVICE_UUID, type: .withResponse)
        }
    }

    public func close() async throws {
        try await centralManager?.cancelPeripheralConnection(peripheral)
        connected = false
    }

    /**
     * Prepare an APDU to be sent over the chosen bearer
     * @param command APDU to send
     * @param packetSize maximum size of a packet for this bearer
     * @return list of packets to be sent over the chosen bearer
     */
    static func wrapCommandAPDU(command: Data, packetSize: Int) throws -> Data? {
        if packetSize < 3 { throw LedgerError.InvalidParameter }
        var buffer = [UInt8]()

        var sequenceIdx: UInt16 = 0
        var offset = 0
        // buffer += [channel >> 8, channel]
        buffer += [TAG_APDU,
                   UInt8(sequenceIdx >> 8),
                   UInt8(sequenceIdx),
                   UInt8(command.count >> 8),
                   UInt8(command.count)]
        sequenceIdx += 1
        var blockSize = command.count > packetSize - 5 ? packetSize - 5 : command.count
        buffer += command[offset..<offset + blockSize]
        offset += blockSize
        while offset != command.count {
            // buffer += [channel >> 8, channel]
            buffer += [TAG_APDU,
                       UInt8(sequenceIdx >> 8),
                       UInt8(sequenceIdx)]
            sequenceIdx += 1
            blockSize = (command.count - offset > packetSize - 5 + 2 ? packetSize - 5 + 2: command.count - offset)
            buffer += command[Int(offset)..<Int(offset + blockSize)]
            offset += blockSize
        }
        if buffer.count % Int(packetSize) != 0 {
            let len = Int(packetSize) - (buffer.count % Int(packetSize))
            let pad = [UInt8](repeating: 0, count: len)
            buffer += pad
        }
        return Data(buffer)
    }

    /**
     * Reassemble packets received over the chosen bearer
     * @param data binary data received so far
     * @param packetSize maximum size of a packet for this bearer
     * @param reassembled response or null if not enough data is available
     */
    // swiftlint:disable cyclomatic_complexity
    static func unwrapResponseAPDU(data: Data, packetSize: Int) throws -> Data {
        var buffer = [UInt8]()
        var offset = 0
        var sequenceIdx: UInt8 = 0
        if data.count < 5 { throw LedgerError.IOError }
        if data[offset] != TAG_APDU { throw LedgerError.IOError }
        if data[offset + 1] != 0x00 { throw LedgerError.IOError }
        if data[offset + 2] != 0x00 { throw LedgerError.IOError }
        var responseLength = (data[offset + 3] & 0xff) << 8
        responseLength |= data[offset + 4] & 0xff
        offset += 5
        if data.count < 5 + responseLength { throw LedgerError.IOError }
        var blockSize = responseLength > packetSize - 5 ? packetSize - 5 : Int(responseLength)
        buffer += data[offset..<Int(offset + blockSize)]
        offset += blockSize

        while buffer.count != responseLength {
            sequenceIdx += 1
            if offset == data.count { throw LedgerError.IOError }
            if data[offset] != TAG_APDU { throw LedgerError.IOError }
            if data[offset + 1] != sequenceIdx >> 8 { throw LedgerError.IOError }
            if data[offset + 2] != sequenceIdx & 0xff { throw LedgerError.IOError }
            offset += 3
            blockSize = Int(responseLength) - buffer.count > packetSize - 5 + 2 ? packetSize - 5 + 2 : Int(responseLength) - buffer.count
            if blockSize > data.count - offset { throw LedgerError.IOError }
            buffer += data[offset..<Int(offset + blockSize)]
            offset += Int(blockSize)
        }
        return Data(buffer)
    }

    /**
     * Prepare an APDU receiving data, exchange it with a device, return the response data and Status Word
     * @param device device to exchange the APDU with
     * @param cla APDU CLA
     * @param ins APDU INS
     * @param p1 APDU P1
     * @param p2 APDU P2
     * @param length length of the data to receive
     * @returns APDU data
     */
    func exchangeAdpu(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8, length: UInt8 = 0) async throws -> Data {
        var buffer = Data([cla, ins, p1, p2])
        if length != 0 {
            buffer.append(contentsOf: [length])
        }
        return try await exchange(buffer)
    }

    /**
     * Prepare an APDU sending data, exchange it with a device, return the response data and Status Word
     * @param device device to exchange the APDU with
     * @param cla APDU CLA
     * @param ins APDU INS
     * @param p1 APDU P1
     * @param p2 APDU P2
     * @param data data to exchange
     * @returns APDU data
     */
    func exchangeAdpu(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8, data: Data) async throws -> Data {
        var buffer = Data([cla, ins, p1, p2, UInt8(data.count)])
        buffer.append(contentsOf: data)
        return try await exchange(buffer)
    }

    public func exchange(_ data: Data) async throws -> Data {
#if DEBUG
        print("=> " + data.map { String(format: "%02hhx", $0) }.joined())
#endif
        guard let buf = try? BleLedgerConnection.wrapCommandAPDU(command: data, packetSize: MTU) else {
            throw GaError.GenericError()
        }
        await semaphore.wait()
        try await write(buf)
        if let buffer = try await read() {
            semaphore.signal()
            let res = try BleLedgerConnection.unwrapResponseAPDU(data: buffer, packetSize: buffer.count)
#if DEBUG
            print("<= " + res.map { String(format: "%02hhx", $0) }.joined())
#endif
            let ignoreSW = reqMtu == data
            if ignoreSW {
                return res
            }
            let command = res[0..<res.count-2]
            let lastSW = (UInt16(res[res.count - 2]) << 8) + UInt16(res[res.count - 1])
            if lastSW != SWCode.SW_OK.rawValue {
                throw SWError(SWCode.init(rawValue: lastSW) ?? SWCode.SW_ABORT)
            }
            return command
        }
        semaphore.signal()
        return Data()
    }

    func exchangeApduSplit(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8, data: Data) async throws -> Data {
        var offset = 0
        var result = Data()
        while offset < data.count {
            let blockLength = (data.count - offset) > 255 ? 255 : data.count - offset
            var buffer = Data([cla, ins, p1, p2, UInt8(blockLength)])
            buffer += data.bytes[offset..<(offset+blockLength)]
            result = try await exchange(buffer)
            offset += blockLength
        }
        return result
    }

    func exchangeApduSplit2(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8, data1: Data, data2: Data) async throws -> Data {
        // If data is empty, just send data2 immediately
        if data1.count == 0 {
            return try await exchangeAdpu(cla: cla, ins: ins, p1: p1, p2: p2, data: data2)
        }
        var offset = 0
        var result = Data()
        var maxBlockSize = 255 - data2.count
        while offset < data1.count {
            let blockLength = (data1.count - offset) > maxBlockSize ? maxBlockSize : data1.count - offset
            let lastBlock = offset + blockLength == data1.count
            var buffer = Data([cla, ins, p1, p2, UInt8(blockLength + (lastBlock ? data2.count : 0))])
            buffer += data1.bytes[offset..<(offset+blockLength)]
            if lastBlock {
                buffer += data2.bytes
            }
            result = try await exchange(buffer)
            offset += blockLength
        }
        return result
    }
}
