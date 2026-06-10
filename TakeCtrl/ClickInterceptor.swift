//
//  ClickInterceptor.swift
//  TakeCtrl
//
//  Created by Zack on 11/24/25.
//

import ApplicationServices
import Combine
import CoreGraphics

enum ClickInterceptorError: Error {
    case failedToCreateEventTap
}

private func globalEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let interceptor = Unmanaged<ClickInterceptor>.fromOpaque(refcon).takeUnretainedValue()

    if (type == .leftMouseDown || type == .leftMouseUp) && interceptor.enableControlFix {
        let flags = event.flags
        if flags.contains(.maskControl) {
            event.flags = flags.subtracting(.maskControl)
        }
    }

    if type == .scrollWheel && interceptor.enableShiftFix {
        let flags = event.flags
        if flags.contains(.maskShift) {
            event.flags = flags.subtracting(.maskShift)
        }
    }

    return Unmanaged.passUnretained(event)
}

class ClickInterceptor: ObservableObject {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var enableControlFix = false
    var enableShiftFix = false

    @Published var isRunning = false
    @Published var hasStartedOnce = false

    private var eventMask: CGEventMask {
        var mask: CGEventMask = 0
        if enableControlFix {
            mask |= (1 << CGEventType.leftMouseDown.rawValue)
            mask |= (1 << CGEventType.leftMouseUp.rawValue)
        }
        if enableShiftFix {
            mask |= (1 << CGEventType.scrollWheel.rawValue)
        }
        return mask
    }

    func start() throws {
        guard !isRunning else { return }

        let mask = eventMask
        guard mask != 0 else { return }

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: globalEventCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else {
            throw ClickInterceptorError.failedToCreateEventTap
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isRunning = true
        hasStartedOnce = true
    }

    func stop() {
        guard isRunning, let tap = eventTap, let source = runLoopSource else {
            return
        }

        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)

        self.eventTap = nil
        self.runLoopSource = nil
        self.isRunning = false
    }

    func getPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    func setEnableControlFix(_ enable: Bool) {
        enableControlFix = enable
        restart()
    }

    func setEnableShiftFix(_ enable: Bool) {
        enableShiftFix = enable
        restart()
    }

    private func restart() {
        stop()
        guard eventMask != 0 else { return }
        do {
            try start()
        } catch {
            print(error)
        }
    }
}
