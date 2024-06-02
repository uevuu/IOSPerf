//
//  TTIObserver.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 06/07/2021.
//

import UIKit

final class TTIObserver: ViewControllerObserver {

    init(
        metricsReceiver: TTIMetricsReceiver, timeProvider: TimeProvider = defaultTimeProvider,
        appStateObserver: AppStateObserver = DefaultAppStateObserver()
    ) {
        self.metricsReceiver = metricsReceiver
        self.timeProvider = timeProvider
        self.appStateObserver = appStateObserver
    }

    private let metricsReceiver: TTIMetricsReceiver
    private let timeProvider: TimeProvider
    private let appStateObserver: AppStateObserver
    private weak var viewController: UIViewController?

    private var screenCreatedTime: DispatchTime?
    private var viewDidAppearTime: DispatchTime?
    private var viewWillAppearTime: DispatchTime?
    private var screenIsReadyTime: DispatchTime?
    private var ttiCalculated = false
    private var sameRunLoopAsTheInit = false
    private var ignoreThisScreen = false

    private static var upcomingCustomCreationTime: DispatchTime?
    private var customCreationTime: DispatchTime?

    static func startCustomCreationTime(timeProvider: TimeProvider = defaultTimeProvider) {
        let now = timeProvider.now()
        PerformanceMonitoring.queue.async {
            upcomingCustomCreationTime = now
        }
    }

    static func clearCustomCreationTime() {
        PerformanceMonitoring.queue.async {
            upcomingCustomCreationTime = nil
        }
    }

    func beforeInit(viewController: UIViewController) {
        let now = timeProvider.now()
        PerformanceMonitoring.queue.async {
            self.sameRunLoopAsTheInit = true
            assert(!self.ttiCalculated)
            assert(self.viewController == nil)
            assert(self.screenCreatedTime == nil)
            self.viewController = viewController
            self.screenCreatedTime = now

            DispatchQueue.main.async {
                PerformanceMonitoring.queue.async {
                    self.sameRunLoopAsTheInit = false
                }
            }
        }
    }

    func beforeViewDidLoad(viewController: UIViewController) {
        let now = timeProvider.now()
        PerformanceMonitoring.queue.async {
            if !self.sameRunLoopAsTheInit {
                assert(!self.ttiCalculated)
                assert(viewController == self.viewController)
                self.screenCreatedTime = now
            }
        }
    }

    func afterViewWillAppear(viewController: UIViewController) {
        let now = timeProvider.now()
        PerformanceMonitoring.queue.async {
            assert(viewController == self.viewController)

            if self.viewWillAppearTime != nil && self.ttiCalculated == false {
                self.ignoreThisScreen = true
            }

            if self.shouldReportTTI && self.viewWillAppearTime == nil {
                self.customCreationTime = Self.upcomingCustomCreationTime
                Self.upcomingCustomCreationTime = nil

                self.viewWillAppearTime = now
            }
        }
    }

    func afterViewDidAppear(viewController: UIViewController) {
        let now = timeProvider.now()
        PerformanceMonitoring.queue.async {
            assert(viewController == self.viewController)
            if self.shouldReportTTI && self.viewDidAppearTime == nil {
                self.viewDidAppearTime = now
                self.reportTTIIfNeeded()
            }
        }
    }

    func beforeViewWillDisappear(viewController: UIViewController) {
        PerformanceMonitoring.queue.async {
            if self.shouldReportTTI && self.screenIsReadyTime == nil {
                self.screenIsReadyTime = self.viewDidAppearTime
                self.reportTTIIfNeeded()
            }
        }
    }

    func beforeViewDidDisappear(viewController: UIViewController) {}

    func screenIsReady() {
        let now = timeProvider.now()
        PerformanceMonitoring.queue.async {
            if self.shouldReportTTI && self.screenIsReadyTime == nil {
                self.screenIsReadyTime = now
                self.reportTTIIfNeeded()
            }
        }
    }

    private func reportTTIIfNeeded() {
        dispatchPrecondition(condition: .onQueue(PerformanceMonitoring.queue))

        guard shouldReportTTI,
            let viewCreatedTime = screenCreatedTime,
            let viewWillAppearTime = viewWillAppearTime,
            let viewDidAppearTime = viewDidAppearTime,
            let screenIsReadyTime = screenIsReadyTime,
            let viewController = viewController
        else {
            return
        }

        let ttiStartTime = customCreationTime ?? viewCreatedTime
        let ttiEndTime = max(screenIsReadyTime, viewDidAppearTime)
        let tti = ttiStartTime.distance(to: ttiEndTime)
        if tti < .zero {
            assertionFailure("We received negative TTI  for \(viewController). That should never happen")
            return
        }

        let ttfrStartTime = max(viewCreatedTime, ttiStartTime)
        let ttfrEndTime = viewWillAppearTime
        let ttfr = ttfrStartTime.distance(to: ttfrEndTime)
        if ttfr < .zero {
            assertionFailure("We received negative TTFR  for \(viewController). That should never happen")
            return
        }


        let metrics = TTIMetrics(tti: tti, ttfr: ttfr, appStartInfo: AppInfoHolder.appStartInfo)
        PerformanceMonitoring.consumerQueue.async {
            self.metricsReceiver.ttiMetricsReceived(metrics: metrics, viewController: viewController)
        }

        self.ttiCalculated = true
    }

    private var shouldReportTTI: Bool {
        return !ttiCalculated && !appStateObserver.wasInBackground && !ignoreThisScreen
    }
}
