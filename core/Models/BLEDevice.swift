import Foundation
import AsyncBluetooth
import gdk
import hw

public class BLEDevice {
    public let peripheral: Peripheral
    public let device: HWDevice
    public let interface: HWProtocol
    public init(peripheral: Peripheral, device: HWDevice, interface: HWProtocol) {
        self.peripheral = peripheral
        self.device = device
        self.interface = interface
    }
}
