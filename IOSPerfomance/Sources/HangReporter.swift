//
//  HangsReporter.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 08/09/2021.
//

import Foundation
import UIKit

public protocol HangsReceiver: AnyObject {

    
    func fatalHangReceived(info: HangInfo)

    func nonFatalHangReceived(info: HangInfo)

    func hangStarted(info: HangInfo)

    var hangThreshold: TimeInterval { get }
}

public extension HangsReceiver {
    var hangThreshold: TimeInterval {
        return 2
    }
}

protocol DidHangPreviouslyProvider: AnyObject {
    func didHangPreviously() -> Bool
}

protocol AppStateProvider: AnyObject {
    var applicationState: UIApplication.State { get }
}

extension UIApplication: AppStateProvider {}

final class HangReporter: AppMetricsReporter, DidHangPreviouslyProvider {

    private let storage: Storage
    private let timeProvider: TimeProvider
    private let startupProvider: StartupProvider
    private let workingQueue: DispatchQueue
    private let detectionTimer: DispatchSourceTimer
    private let detectionTimerInterval: DispatchTimeInterval
    private let didCrashPreviously: Bool
    private let enabledInDebug: Bool

    private var lastMainThreadDate: DispatchTime
    private var isSuspended = false
    private var startupIsHappening = true

    private let hangThreshold: DispatchTimeInterval

    private var willResignSubscription: AnyObject?
    private var didBecomeActiveSubscription: AnyObject?

    private let receiver: HangsReceiver

    init(
        timeProvider: TimeProvider = DefaultTimeProvider(),
        storage: Storage = UserDefaults.standard,
        startupProvider: StartupProvider,
        appStateProvider: AppStateProvider = UIApplication.shared,
        workingQueue: DispatchQueue = PerformanceMonitoring.queue,
        detectionTimerInterval: DispatchTimeInterval,
        hangThreshold: DispatchTimeInterval,
        didCrashPreviously: Bool = false,
        enabledInDebug: Bool = false,
        receiver: HangsReceiver
    ) {
        self.timeProvider = timeProvider
        self.storage = storage
        self.startupProvider = startupProvider
        self.workingQueue = workingQueue
        self.detectionTimerInterval = detectionTimerInterval
        self.hangThreshold = hangThreshold
        self.didCrashPreviously = didCrashPreviously
        self.enabledInDebug = enabledInDebug
        self.receiver = receiver
        self.lastMainThreadDate = timeProvider.now()
        self.detectionTimer = DispatchSource.makeTimerSource(flags: .strict, queue: workingQueue)

        let prewarming = AppInfoHolder.appStartInfo.appStartedWithPrewarming
        let stateResolver = { appStateProvider.applicationState == .background || prewarming }
        let inBackground = Thread.isMainThread ? stateResolver() : DispatchQueue.main.sync { stateResolver() }

        self.workingQueue.async {
            self.notifyAboutFatalHangs()

            self.startupProvider.notifyAfterAppStarted { [weak self] in
                self?.workingQueue.async {
                    self?.startupIsHappening = false
                    self?.lastMainThreadDate = timeProvider.now()
                }
            }

            self.start(inBackground: inBackground)
        }
    }

    private func start(inBackground: Bool) {
        lastMainThreadDate = timeProvider.now()
        scheduleDetectionTimer(inBackground: inBackground)
        subscribeToApplicationEvents()
    }

    private func scheduleDetectionTimer(inBackground: Bool) {
        detectionTimer.schedule(deadline: .now() + detectionTimerInterval, repeating: detectionTimerInterval)
        detectionTimer.setEventHandler { [weak self] in
            self?.detect()
        }
        if inBackground {
            isSuspended = true
        } else {
            detectionTimer.resume()
        }
    }

    private func notifyAboutFatalHangs() {
        guard let info = readAndClearHangInfo() else {
            return
        }
        guard !didCrashPreviously else {
            // if it crashed during hang, we do not report this as a hang, as it will be probably reported as a crash
            return
        }
#if DEBUG
        if !self.enabledInDebug {
            // In debug we can just pause on the breakpoint and this might be considered as a hang,
            // that's why in Debug we send events only in unit-tests. Or you may enable it manually to debug.
            return
        }
#endif
        PerformanceMonitoring.consumerQueue.async {
            self.receiver.fatalHangReceived(info: info)
        }
    }

    private func subscribeToApplicationEvents() {
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = workingQueue
        didBecomeActiveSubscription = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: operationQueue
        ) { [weak self] _ in
            guard let self = self else {
                return
            }
            dispatchPrecondition(condition: .onQueue(self.workingQueue))
            if self.isSuspended {
                self.detectionTimer.resume()
                self.isSuspended = false
            }
            self.lastMainThreadDate = self.timeProvider.now()
        }

        willResignSubscription = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: operationQueue
        ) { [weak self] _ in
            guard let self = self else {
                return
            }
            dispatchPrecondition(condition: .onQueue(self.workingQueue))
            if !self.isSuspended {
                self.detectionTimer.suspend()
                self.isSuspended = true
            }
        }
    }

    private func detect() {
        dispatchPrecondition(condition: .onQueue(self.workingQueue))
        guard !isSuspended else {
            return
        }

        let hangInterval = currentHangInterval.milliseconds ?? 0
        let hangThreshold = hangThreshold.milliseconds ?? 0

        if var info = hangInfoInMemory {
            info.duration = currentHangInterval
            store(hangInfo: info)
        } else {
            if hangInterval > hangThreshold {
                let callStack: String
#if arch(arm64)
                callStack = (try? MainThreadCallStack.readStack()) ?? ""
#else
                callStack = ""
#endif
                let info = HangInfo.with(callStack: callStack, duringStartup: startupIsHappening, duration: currentHangInterval)
                store(hangInfo: info)

#if DEBUG
                if !self.enabledInDebug {
                    return
                }
#endif
                PerformanceMonitoring.consumerQueue.async {
                    self.receiver.hangStarted(info: info)
                }
            }
        }

        DispatchQueue.main.async {
            self.workingQueue.async {
                self.onMainThreadIsActive()
            }
        }
    }

    private func onMainThreadIsActive() {
        if var info = hangInfoInMemory {
            clearHangInfo()
            info.duration = currentHangInterval
            PerformanceMonitoring.consumerQueue.async {
#if DEBUG
                if !self.enabledInDebug {
                    return
                }
#endif
                self.receiver.nonFatalHangReceived(info: info)
            }
        }
        // we update date every time to measure hang when it started
        self.lastMainThreadDate = self.timeProvider.now()
    }

    private var currentHangInterval: DispatchTimeInterval {
        let now = timeProvider.now()
        return lastMainThreadDate.advanced(by: detectionTimerInterval).distance(to: now)
    }

    private func readAndClearHangInfo() -> HangInfo? {
        let result: HangInfo? = storage.readJSON(key: StorageKey.hangInfo)
        didHangPreviouslyValue = result != nil
        clearHangInfo()
        return result
    }

    private func store(hangInfo: HangInfo) {
        hangInfoInMemory = hangInfo
        storage.writeJSON(key: StorageKey.hangInfo, value: hangInfo)
    }

    private func clearHangInfo() {
        hangInfoInMemory = nil
        storage.writeJSON(key: StorageKey.hangInfo, value: nil as HangInfo?)
    }

    deinit {
        if self.isSuspended {
            detectionTimer.resume()
        }
        detectionTimer.cancel()
    }

    func didHangPreviously() -> Bool {
        if let didHangPreviouslyValue = didHangPreviouslyValue {
            return didHangPreviouslyValue
        }
        let result = (storage.readJSON(key: StorageKey.hangInfo) as HangInfo? != nil)
        didHangPreviouslyValue = result
        return result
    }
    private var didHangPreviouslyValue: Bool?

    private var hangInfoInMemory: HangInfo?

    enum StorageKey: String {
        case hangInfo
    }
}
