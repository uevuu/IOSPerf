//
//  FramesMeter.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 07/07/2021.
//

import QuartzCore
import UIKit

protocol FramesMeterReceiver: AnyObject {

    func frameTicked(frameDuration: CFTimeInterval, refreshRateDuration: CFTimeInterval)
}

protocol FramesMeter {
    func subscribe(receiver: FramesMeterReceiver)
    func unsubscribe(receiver: FramesMeterReceiver)
}

private class DisplayLinkProxy {
    init(displayLinkUpdatedAction: @escaping () -> Void) {
        self.displayLinkUpdatedAction = displayLinkUpdatedAction
    }
    private let displayLinkUpdatedAction: () -> Void

    @objc func displayLinkUpdated() {
        displayLinkUpdatedAction()
    }
}

final class DefaultFramesMeter: FramesMeter {

    init(appStateObserver: AppStateObserver = DefaultAppStateObserver()) {
        self.appStateObserver = appStateObserver
        appStateObserver.didChange = { [weak self] in
            self?.updateState()
        }
    }

    private lazy var displayLink: CADisplayLink = {
        let proxy = DisplayLinkProxy { [weak self] in
            self?.displayLinkUpdated()
        }
        let displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.displayLinkUpdated))
        displayLink.add(to: .main, forMode: .common)
        displayLink.isPaused = true
        return displayLink
    }()

    private var previousTimestamp: CFTimeInterval?
    private var previousDuration: CFTimeInterval?

    // can't use FramesMeterReceiver as a generic type parameter here, so let's live with AnyObject
    private var receivers = NSHashTable<AnyObject>.weakObjects()

    private let appStateObserver: AppStateObserver

    func subscribe(receiver: FramesMeterReceiver) {
        PerformanceMonitoring.queue.async {
            self.receivers.add(receiver)
            self.updateState()
        }
    }

    func unsubscribe(receiver: FramesMeterReceiver) {
        PerformanceMonitoring.queue.async {
            self.receivers.remove(receiver)
            self.updateState()
        }
    }

    private func updateState() {
        dispatchPrecondition(condition: .onQueue(PerformanceMonitoring.queue))

        
        let hasReceivers = (receivers.count > 0)
        let isInBackground = appStateObserver.isInBackground
        let isPaused = displayLink.isPaused
        let shouldBePaused = isInBackground || !hasReceivers

        if !isPaused && shouldBePaused {
            displayLink.isPaused = true
        }
        if isPaused && !shouldBePaused {
            previousTimestamp = nil
            displayLink.isPaused = false
        }
    }

    private func displayLinkUpdated() {
        let timestamp = self.displayLink.timestamp
        let targetTimestamp = self.displayLink.targetTimestamp
        let displayLinkDuration = self.displayLink.duration
        PerformanceMonitoring.queue.async {
            if self.appStateObserver.isInBackground {
                return
            }
            if let previousTimestamp = self.previousTimestamp {
                let previousDuration = self.previousDuration ?? 0
                var actualFrameDuration = timestamp - previousTimestamp
                let targetFrameDuration = targetTimestamp - timestamp

                let fpsIsChanging =
                    notEqual(previousDuration, displayLinkDuration) || notEqual(targetFrameDuration, displayLinkDuration)
            
                let noMoreThan1DroppedFrame =
                    (actualFrameDuration < 2 * targetFrameDuration + RenderingMetrics.refreshRateDurationThreshold)
                if fpsIsChanging && noMoreThan1DroppedFrame {
                    actualFrameDuration = targetFrameDuration
                }
                self.receivers.allObjects.forEach {
                    ($0 as? FramesMeterReceiver)?.frameTicked(
                        frameDuration: actualFrameDuration, refreshRateDuration: targetFrameDuration)
                }
                self.previousDuration = displayLinkDuration
            }
            self.previousTimestamp = timestamp
        }
    }

    deinit {
        self.displayLink.invalidate()
    }
}

private func notEqual(_ lhs: Double, _ rhs: Double) -> Bool {
    return abs(lhs - rhs) < RenderingMetrics.refreshRateDurationThreshold
}
