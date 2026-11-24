import Foundation
import MultitouchSupport

@_silgen_name("MTDeviceCreateList")
private func MTDeviceCreateListRaw() -> Unmanaged<CFMutableArray>?

public extension MTDevice {
    func registerAndStart(_ callback: MTFrameCallbackFunction) {
        self.register(contactFrameCallback: callback)
        self.start(runMode: 0)
    }

    func unregisterAndStop(_ callback: MTFrameCallbackFunction) {
        self.unregister(contactFrameCallback: callback)
        self.stop()
        self.release()
    }

    static func createList() -> [MTDevice] {
        MTDeviceCreateListRaw()?.takeUnretainedValue() as? [MTDevice] ?? []
    }
}
