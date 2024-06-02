//
//  FragmentTTIReporter.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 21/12/2022.
//

import Foundation


public protocol FragmentTTITrackable: AnyObject {
 
    func fragmentIsRendered()
    func fragmentIsReady()
}

public protocol FragmentTTIMetricsReceiver: AnyObject {
    func fragmentTTIMetricsReceived(metrics: TTIMetrics, identifier: String)
}

private class Trackable: FragmentTTITrackable {

    private let identifier: String
    private let timeProvider: TimeProvider
    private let metricsReceiver: FragmentTTIMetricsReceiver
    private let appStateObserver: AppStateObserver
    private weak var reporter: FragmentTTIReporter?

    private let createdTime: DispatchTime
    private var isRenderedTime: DispatchTime?
    private var ttiCalculated = false


    init(
        identifier: String,
        timeProvider: TimeProvider,
        metricsReceiver: FragmentTTIMetricsReceiver,
        appStateObserver: AppStateObserver,
        reporter: FragmentTTIReporter
    ) {
        self.identifier = identifier
        self.timeProvider = timeProvider
        self.metricsReceiver = metricsReceiver
        self.appStateObserver = appStateObserver
        self.reporter = reporter
        self.createdTime = timeProvider.now()
    }

    func fragmentIsRendered() {
        let now = timeProvider.now()
        PerformanceMonitoring.queue.async {
            self.isRenderedTime = now
        }
    }

    func fragmentIsReady() {
        let now = timeProvider.now()
        PerformanceMonitoring.queue.async {
            self.reportTTI(now: now)
        }
    }

    private func reportTTI(now: DispatchTime) {
        dispatchPrecondition(condition: .onQueue(PerformanceMonitoring.queue))
        if ttiCalculated {
            return
        }

        if appStateObserver.wasInBackground {
            return
        }


        let ttiStartTime = createdTime
        let ttiEndTime = now
        let tti = ttiStartTime.distance(to: ttiEndTime)
        if tti < .zero {
            assertionFailure("We received negative TTI  for \(identifier) that should never happen")
            return
        }

        let ttfrStartTime = createdTime
        let ttfrEndTime = isRenderedTime ?? now
        let ttfr = ttfrStartTime.distance(to: ttfrEndTime)
        if ttfr < .zero {
            assertionFailure("We received negative TTFR  for \(identifier) that should never happen")
            return
        }

        let metrics = TTIMetrics(tti: tti, ttfr: ttfr, appStartInfo: AppInfoHolder.appStartInfo)
        PerformanceMonitoring.consumerQueue.async {
            self.metricsReceiver.fragmentTTIMetricsReceived(metrics: metrics, identifier: self.identifier)
        }

        ttiCalculated = true
    }
}

class FragmentTTIReporter: AppMetricsReporter {

    init(
        metricsReceiver: FragmentTTIMetricsReceiver, timeProvider: TimeProvider = defaultTimeProvider,
        appStateObserverFactory: @escaping () -> AppStateObserver = { DefaultAppStateObserver() }
    ) {
        self.metricsReceiver = metricsReceiver
        self.timeProvider = timeProvider
        self.appStateObserverFactory = appStateObserverFactory
    }

    private let metricsReceiver: FragmentTTIMetricsReceiver
    private let timeProvider: TimeProvider
    private let appStateObserverFactory: () -> AppStateObserver

    func start(identifier: String) -> FragmentTTITrackable {
        let fragment = Trackable(
            identifier: identifier,
            timeProvider: timeProvider,
            metricsReceiver: metricsReceiver,
            appStateObserver: appStateObserverFactory(),
            reporter: self)
        return fragment
    }
}

class EmptyFragmentTTITrackable: FragmentTTITrackable {
    func fragmentIsReady() {
        preconditionFailure("You've called startFragmentTTI without registering FragmentTTIReceiver")
    }
    func fragmentIsRendered() {
        preconditionFailure("You've called startFragmentTTI without registering FragmentTTIReceiver")
    }
}


dynamic func preconditionFailure(_ message: String, file: StaticString = #file, line: UInt = #line) {
    Swift.preconditionFailure(message, file: file, line: line)
}
