//
//  AppRenderingReporter.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 21/12/2021.
//

import Foundation


public protocol AppRenderingMetricsReceiver: AnyObject {

    func appRenderingMetricsReceived(metrics: RenderingMetrics)
}


final class AppRenderingReporter: FramesMeterReceiver, AppMetricsReporter {

    init(metricsReceiver: AppRenderingMetricsReceiver, framesMeter: FramesMeter, sendingThrottleInterval: TimeInterval = 5) {
        self.metricsReceiver = metricsReceiver
        self.framesMeter = framesMeter
        self.sendingThrottleInterval = sendingThrottleInterval

        PerformanceMonitoring.queue.asyncAfter(deadline: .now() + sendingThrottleInterval) {
            framesMeter.subscribe(receiver: self)
        }
    }

    private let metricsReceiver: AppRenderingMetricsReceiver
    private let framesMeter: FramesMeter
    private var metrics = RenderingMetrics.zero
    private var scheduledSending: DispatchWorkItem?
    private let sendingThrottleInterval: TimeInterval

    func frameTicked(frameDuration: CFTimeInterval, refreshRateDuration: CFTimeInterval) {
        dispatchPrecondition(condition: .onQueue(PerformanceMonitoring.queue))
        let currentMetrics = RenderingMetrics.metrics(frameDuration: frameDuration, refreshRateDuration: refreshRateDuration)
        self.metrics = self.metrics + currentMetrics
        guard currentMetrics.droppedFrames > 0 else {
            return
        }
        scheduledSending?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.reportMetrics()
        }
        scheduledSending = workItem
        PerformanceMonitoring.queue.asyncAfter(deadline: .now() + .init(sendingThrottleInterval), execute: workItem)
    }

    func reportMetrics() {
        dispatchPrecondition(condition: .onQueue(PerformanceMonitoring.queue))
        let metrics = self.metrics
        self.metrics = .zero
        PerformanceMonitoring.consumerQueue.async {
            self.metricsReceiver.appRenderingMetricsReceived(metrics: metrics)
        }
    }
}
