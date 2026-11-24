import Foundation
import IOKit

final class IOMultitouchMonitor {
    private var notifyPort: IONotificationPortRef?
    private var iterator: io_iterator_t = 0
    private let onDeviceAdded: () -> Void
    private var isInitialPass = true

    init(onDeviceAdded: @escaping () -> Void) {
        self.onDeviceAdded = onDeviceAdded
    }

    func start() {
        stop()
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notifyPort = port

        let runLoopSource = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        let matching = IOServiceMatching("AppleMultitouchDevice")
        let refCon = Unmanaged.passUnretained(self).toOpaque()

        let callback: IOServiceMatchingCallback = { refCon, iter in
            guard let refCon else { return }
            let monitor = Unmanaged<IOMultitouchMonitor>.fromOpaque(refCon).takeUnretainedValue()
            var foundAny = false
            while true {
                let device = IOIteratorNext(iter)
                if device == 0 { break }
                IOObjectRelease(device)
                foundAny = true
            }
            if foundAny && !monitor.isInitialPass {
                monitor.onDeviceAdded()
            }
        }

        let kr = IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            matching,
            callback,
            refCon,
            &iterator
        )
        if kr == KERN_SUCCESS {
            // Drain initial existing devices
            callback(refCon, iterator)
            isInitialPass = false
        }
    }

    func stop() {
        if iterator != 0 {
            IOObjectRelease(iterator)
            iterator = 0
        }
        if let port = notifyPort {
            IONotificationPortDestroy(port)
            notifyPort = nil
        }
        isInitialPass = true
    }

    deinit {
        stop()
    }
}
