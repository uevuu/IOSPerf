//
//  StartupTimeReporter.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 29.03.2022
//


import UIKit

public struct StartupTimeData {

    
    public let totalTime: DispatchTimeInterval

    public let preMainTime: DispatchTimeInterval?


    public let mainTime: DispatchTimeInterval?


    public let totalBeforeViewControllerTime: DispatchTimeInterval

    public let mainBeforeViewControllerTime: DispatchTimeInterval?

  
    public let appStartInfo: AppStartInfo
}

protocol StartupProvider {
    var appIsStarting: Bool { get }

    func notifyAfterAppStarted(_ action: @escaping () -> Void)
}

final class StartupTimeReporter: AppMetricsReporter, StartupProvider {

    private let receiver: StartupTimeReceiver
    private var viewDidLoadTime: TimeInterval?
    private var isStarting = true
    private var onStartedActions: [() -> Void] = []

    private static var mainStartedTime: TimeInterval?

    init(receiver: StartupTimeReceiver) {
        self.receiver = receiver
    }

    static func recordMainStarted() {
        assert(Thread.isMainThread)
        assert(mainStartedTime == nil)
        mainStartedTime = currentTime()
    }

    static func forgetMainStartedForTests() {
        mainStartedTime = nil
    }

    func onViewDidLoadOfTheFirstViewController() {
        viewDidLoadTime = Self.currentTime()
    }

    func onViewDidAppearOfTheFirstViewController() {
        guard let viewDidLoadTime = viewDidLoadTime else {

            return
        }
        let viewDidAppearTime = Self.currentTime()
        let processStartTime = Self.processStartTime()

        let totalTimeInterval = viewDidAppearTime - processStartTime
        let totalTime = toDispatchInterval(totalTimeInterval)

        let totalBeforeViewControllerTimeInterval = viewDidLoadTime - processStartTime
        let totalBeforeViewControllerTime = toDispatchInterval(totalBeforeViewControllerTimeInterval)

        var preMainTime: DispatchTimeInterval?
        var mainTime: DispatchTimeInterval?
        var mainBeforeViewControllerTime: DispatchTimeInterval?
        if let mainStartedTime = Self.mainStartedTime {
            let preMainTimeInterval = mainStartedTime - processStartTime
            preMainTime = toDispatchInterval(preMainTimeInterval)

            let mainTimeInterval = viewDidAppearTime - mainStartedTime
            mainTime = toDispatchInterval(mainTimeInterval)

            let mainBeforeViewControllerTimeInterval = viewDidLoadTime - mainStartedTime
            mainBeforeViewControllerTime = toDispatchInterval(mainBeforeViewControllerTimeInterval)
        }

        let data = StartupTimeData(
            totalTime: totalTime,
            preMainTime: preMainTime,
            mainTime: mainTime,
            totalBeforeViewControllerTime: totalBeforeViewControllerTime,
            mainBeforeViewControllerTime: mainBeforeViewControllerTime,
            appStartInfo: AppInfoHolder.appStartInfo
        )
        PerformanceMonitoring.consumerQueue.async {
            self.receiver.startupTimeReceived(data)
        }

        PerformanceMonitoring.queue.async {
            self.isStarting = false
            self.onStartedActions.forEach { $0() }
            self.onStartedActions.removeAll()
        }
    }

    func makeViewControllerObserver() -> ViewControllerObserver {
        return StartupTimeViewControllerObserver(reporter: self)
    }

    // MARK: - Time utils

    private static func processStartTime() -> TimeInterval {
        var kinfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        sysctl(&mib, u_int(mib.count), &kinfo, &size, nil, 0)
        let startTime = kinfo.kp_proc.p_starttime
        return TimeInterval(startTime.tv_sec) + TimeInterval(startTime.tv_usec) / 1e6
    }

    private static func currentTime() -> TimeInterval {
        return CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970
    }

    private func toDispatchInterval(_ timeInterval: TimeInterval) -> DispatchTimeInterval {
        let milliseconds = round(timeInterval * 1000)
        return DispatchTimeInterval.milliseconds(Int(milliseconds))
    }

    // MARK: - StartupProvider

    var appIsStarting: Bool {
        dispatchPrecondition(condition: .onQueue(PerformanceMonitoring.queue))
        return isStarting
    }

    func notifyAfterAppStarted(_ action: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(PerformanceMonitoring.queue))
        if isStarting {
            onStartedActions.append(action)
        } else {
            action()
        }
    }
}

/// We need this observer to catch the first `viewWillAppear` call from the first appeared view controller.
final class StartupTimeViewControllerObserver: ViewControllerObserver {
    private let reporter: StartupTimeReporter
    private var viewDidLoadCalled = false
    private var viewDidAppearCalled = false

    init(reporter: StartupTimeReporter) {
        self.reporter = reporter
    }

    func beforeViewDidLoad(viewController: UIViewController) {
        guard !viewDidLoadCalled else {
            return
        }
        viewDidLoadCalled = true
        reporter.onViewDidLoadOfTheFirstViewController()
    }

    func afterViewDidAppear(viewController: UIViewController) {
        guard !viewDidAppearCalled else {
            return
        }
        viewDidAppearCalled = true
        reporter.onViewDidAppearOfTheFirstViewController()
    }

    func beforeInit(viewController: UIViewController) {}
    func afterViewWillAppear(viewController: UIViewController) {}
    func beforeViewWillDisappear(viewController: UIViewController) {}
    func beforeViewDidDisappear(viewController: UIViewController) {}
}
