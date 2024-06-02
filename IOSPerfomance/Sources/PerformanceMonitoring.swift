//
//  PerformanceMonitoring.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 05/07/2021.
//

import UIKit

protocol AppMetricsReporter: AnyObject {}

public struct Experiments {
    public init() { }
}

public enum PerformanceMonitoring {

    private static var appReporters: [AppMetricsReporter] = []
    private static let lock = NSLock()
    private static var viewControllerSubscriberEnabled = false
    static var experiments = Experiments()


    public static func enable(
        config: Config = [],
        storage: Storage = UserDefaults.standard,
        didCrashPreviously: Bool = false,
        experiments: Experiments = Experiments()
    ) throws {
        lock.lock()
        defer {
            lock.unlock()
        }

        Self.experiments = experiments

        guard self.appReporters.isEmpty && !viewControllerSubscriberEnabled else {
            assertionFailure("You cannot call `enable` twice. Should `disable` before that.")
            return
        }

        let (vcObservers, appReporters) = makeObservers(config: config, storage: storage, didCrashPreviously: didCrashPreviously)
        if !vcObservers.isEmpty {
            let observersCollection = ViewControllerObserverCollection(observers: vcObservers)
            try ViewControllerSubscriber().subscribeObserver(observersCollection)
        }
        self.appReporters = appReporters
        self.viewControllerSubscriberEnabled = !vcObservers.isEmpty
    }


    public static func disable() throws {
        lock.lock()
        defer {
            lock.unlock()
        }
        if viewControllerSubscriberEnabled {
            try ViewControllerSubscriber().unsubscribeObservers()
        }

        appReporters = []
        viewControllerSubscriberEnabled = false
        experiments = Experiments()
    }

    public static func onMainStarted() {
        StartupTimeReporter.recordMainStarted()
        AppInfoHolder.recordMainStarted()
        #if arch(arm64)
            precondition(Thread.isMainThread)
            MainThreadCallStack.storeMainThread()
        #endif
    }

    public static func startFragmentTTI(identifier: String) -> FragmentTTITrackable {
        lock.lock()
        defer {
            lock.unlock()
        }
        if let reporter = appReporters.compactMap({ $0 as? FragmentTTIReporter }).first {
            return reporter.start(identifier: identifier)
        } else {
            return EmptyFragmentTTITrackable()
        }
    }


    public static var appStartInfo: AppStartInfo {
        return AppInfoHolder.appStartInfo
    }

    private static func appendTTIObservers(config: Config, vcObservers: inout [ViewControllerObserver]) {
        guard let screenTTIReceiver = config.screenTTIReceiver else {
            return
        }
        let ttiFactory = ViewControllerObserverFactory<TTIObserver>(metricsReceiver: screenTTIReceiver) {
            TTIObserver(metricsReceiver: screenTTIReceiver)
        }
        vcObservers.append(ttiFactory)
    }

    private static func appendRenderingObservers(
        config: Config, vcObservers: inout [ViewControllerObserver], appReporters: inout [AppMetricsReporter]
    ) {
        guard config.renderingEnabled else {
            return
        }
        let framesMeter = DefaultFramesMeter()

        if let screenRenderingReceiver = config.screenRenderingReceiver {
            let renderingFactory = ViewControllerObserverFactory<RenderingObserver>(metricsReceiver: screenRenderingReceiver) {
                RenderingObserver(metricsReceiver: screenRenderingReceiver, framesMeter: framesMeter)
            }
            vcObservers.append(renderingFactory)
        }

        if let appRenderingReceiver = config.appRenderingReceiver {
            #if PERFORMANCE_TESTS
                let appRenderingReporter = AppRenderingReporter(
                    metricsReceiver: appRenderingReceiver, framesMeter: framesMeter, sendingThrottleInterval: 0.3)
            #else
                let appRenderingReporter = AppRenderingReporter(metricsReceiver: appRenderingReceiver, framesMeter: framesMeter)
            #endif
            appReporters.append(appRenderingReporter)
        }
    }

    private static func appendStartupObservers(
        config: Config, vcObservers: inout [ViewControllerObserver], appReporters: inout [AppMetricsReporter]
    ) -> StartupProvider? {
        guard let startupTimeReceiver = config.startupTimeReceiver else {
            return nil
        }
        let startupTimeReporter = StartupTimeReporter(receiver: startupTimeReceiver)
        let startupTimeObserver = startupTimeReporter.makeViewControllerObserver()
        appReporters.append(startupTimeReporter)
        vcObservers.append(startupTimeObserver)
        return startupTimeReporter
    }

    private static func appendWatchdogTerminationsObserver(
        config: Config, dependencies: TerminationDependencies, didHangPreviouslyProvider: DidHangPreviouslyProvider?,
        appReporters: inout [AppMetricsReporter]
    ) {
        guard let watchdogTerminationsReceiver = config.watchdogTerminationsReceiver else {
            return
        }

        if let startupProvider = dependencies.startupProvider {
            let watchdogTerminationsReporter = WatchdogTerminationReporter(storage: dependencies.storage,
                                                                           didCrashPreviously: dependencies.didCrashPreviously,
                                                                           didHangPreviouslyProvider: didHangPreviouslyProvider,
                                                                           startupProvider: startupProvider,
                                                                           receiver: watchdogTerminationsReceiver)
            appReporters.append(watchdogTerminationsReporter)
        } else {
            fatalError("Startup time reporting is needed to enable watchdog terminations reporting. Please pass `.startupTime(_)` in the config.")
        }
    }

    private static func appendHangObservers(
        config: Config,
        dependencies: TerminationDependencies,
        appReporters: inout [AppMetricsReporter]
    ) -> DidHangPreviouslyProvider? {
        guard let hangsReceiver = config.hangsReceiver else {
            return nil
        }
        if let startupProvider = dependencies.startupProvider {
            precondition(hangsReceiver.hangThreshold > 0)
            let hangTreshold = DispatchTimeInterval.timeInterval(hangsReceiver.hangThreshold)
            let detectionTimerInterval = DispatchTimeInterval.timeInterval(hangsReceiver.hangThreshold / 2)
            let hangReporter = HangReporter(storage: dependencies.storage,
                                            startupProvider: startupProvider,
                                            detectionTimerInterval: detectionTimerInterval,
                                            hangThreshold: hangTreshold,
                                            didCrashPreviously: dependencies.didCrashPreviously,
                                            receiver: hangsReceiver)
            appReporters.append(hangReporter)

            #if arch(arm64)
                DispatchQueue.main.async {
                    // if `PerformanceMonitoring.onMainStarted` wasn't called, save mach port at least here.
                    MainThreadCallStack.storeMainThread()
                }
            #endif
            return hangReporter
        } else {
            fatalError("Startup time reporting is needed to enable hangs reporting. Please pass `.startupTime(_)` in the config.")
        }
    }

    private static func appendLeaksObservers(config: Config, vcObservers: inout [ViewControllerObserver]) {
        guard let leaksReceiver = config.viewControllerLeaksReceiver else {
            return
        }
        let leaksObserver = ViewControllerLeaksObserver(metricsReceiver: leaksReceiver)
        vcObservers.append(leaksObserver)
    }

    private static func appendLoggingObservers(config: Config, vcObservers: inout [ViewControllerObserver]) {
        guard let loggingReceiver = config.loggingReceiver else {
            return
        }
        let loggingObserver = LoggingObserver(receiver: loggingReceiver)
        vcObservers.append(loggingObserver)
    }

    private static func appendFragmentTTIRepoter(config: Config, appReporters: inout [AppMetricsReporter]) {
        guard let fragmentTTIReceiver = config.fragmentTTIReceiver else {
            return
        }
        let fragmentTTIReporter = FragmentTTIReporter(metricsReceiver: fragmentTTIReceiver)
        appReporters.append(fragmentTTIReporter)
    }

    private static func makeObservers(config: Config, storage: Storage, didCrashPreviously: Bool) -> (
        [ViewControllerObserver], [AppMetricsReporter]
    ) {
        var vcObservers = [ViewControllerObserver]()
        var appReporters = [AppMetricsReporter]()

        appendTTIObservers(config: config, vcObservers: &vcObservers)
        appendRenderingObservers(config: config, vcObservers: &vcObservers, appReporters: &appReporters)
        let startupProvider = appendStartupObservers(config: config, vcObservers: &vcObservers, appReporters: &appReporters)
        let deps = TerminationDependencies(startupProvider: startupProvider, storage: storage, didCrashPreviously: didCrashPreviously)

        let didHangPreviouslyProvider = appendHangObservers(
            config: config,
            dependencies: deps,
            appReporters: &appReporters
        )
        appendWatchdogTerminationsObserver(
            config: config,
            dependencies: deps,
            didHangPreviouslyProvider: didHangPreviouslyProvider,
            appReporters: &appReporters
        )
        appendLeaksObservers(config: config, vcObservers: &vcObservers)
        appendLoggingObservers(config: config, vcObservers: &vcObservers)
        appendFragmentTTIRepoter(config: config, appReporters: &appReporters)

        return (vcObservers, appReporters)
    }
    @discardableResult
    static func changeQueueForTests(_ newQueue: DispatchQueue) -> DispatchQueue {
        let oldQueue = queue
        queue = newQueue
        return oldQueue
    }

    static private(set) var queue = DispatchQueue(label: "performance_suite_monitoring_queue", qos: .userInteractive)

    static let consumerQueue = DispatchQueue(label: "performance_suite_consumer_queue", qos: .background)
}

private struct TerminationDependencies {
    let startupProvider: StartupProvider?
    let storage: Storage
    let didCrashPreviously: Bool
}
