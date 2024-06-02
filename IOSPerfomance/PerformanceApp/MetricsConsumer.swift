//
//  MetricsConsumer.swift
//  PerformanceApp
//
//  Created by Maryin Nikita on 29/04/2024.
//

import Foundation
import OSLog
import PerformanceSuite
import SwiftUI

extension UIHostingController: PerformanceTrackable {
    var performanceScreen: PerformanceScreen? {
        return (introspectRootView() as? PerformanceTrackable)?.performanceScreen
    }
}

class MetricsConsumer: PerformanceSuiteMetricsReceiver {

    let interop = UITestsHelper.isInTests ? UITestsInterop.Server() : nil

    func appRenderingMetricsReceived(metrics: RenderingMetrics) {
        log("Вот такие метрики  \(metrics)")
        interop?.send(message: Message.appFreezeTime(duration: metrics.freezeTime.milliseconds ?? -1))
    }

    func ttiMetricsReceived(metrics: TTIMetrics, viewController: UIViewController) {
        guard let screen = (viewController as? PerformanceTrackable)?.performanceScreen?.rawValue else {
            fatalError("unknown screen")
        }

        log("TTIMetrics \(screen) \(metrics)")
        interop?.send(message: Message.tti(duration: metrics.tti.milliseconds ?? -1, screen: screen))
    }

    func renderingMetricsReceived(metrics: RenderingMetrics, viewController: UIViewController) {
        guard let screen = (viewController as? PerformanceTrackable)?.performanceScreen?.rawValue else {
            fatalError("unknown screen")
        }
        log("RenderingMetrics \(screen) \(metrics)")
        interop?.send(message: Message.freezeTime(duration: metrics.freezeTime.milliseconds ?? -1, screen: screen))
    }

    func shouldTrack(viewController: UIViewController) -> Bool {
        return (viewController as? PerformanceTrackable)?.performanceScreen != nil
    }


    func viewControllerLeakReceived(viewController: UIViewController) {
        log("View controller leak \(viewController)")
        interop?.send(message: Message.memoryLeak)
    }

    func startupTimeReceived(_ data: StartupTimeData) {
        log("Startup time received \(data.totalTime.milliseconds ?? 0) ms")
        interop?.send(message: Message.startupTime(duration: data.totalTime.milliseconds ?? -1))
    }

    func fragmentTTIMetricsReceived(metrics: TTIMetrics, identifier: String) {
        log("fragmentTTIMetricsReceived \(identifier) \(metrics)")
        interop?.send(message: Message.fragmentTTI(duration: metrics.tti.milliseconds ?? -1, fragment: identifier))
    }

    func fatalHangReceived(info: HangInfo) {
        log("фатальное зависание: \(info)")
        interop?.send(message: Message.fatalHang)
    }

    func nonFatalHangReceived(info: HangInfo) {
        log("Нефатальное зависание: \(info)")
        interop?.send(message: Message.nonFatalHang)
    }

    func hangStarted(info: HangInfo) {
        log("hangStarted \(info)")
        interop?.send(message: Message.hangStarted)
    }

    private func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    // MARK: - ViewControllerLoggingReceiver

    func key(for viewController: UIViewController) -> String {
        return String(describing: viewController)
    }

    func onInit(viewControllerKey: String) {
        log("onInit \(viewControllerKey)")
    }

    func onViewDidLoad(viewControllerKey: String) {
        log("onViewDidLoad \(viewControllerKey)")
    }

    func onViewWillAppear(viewControllerKey: String) {
        log("onViewWillAppear \(viewControllerKey)")
    }

    func onViewDidAppear(viewControllerKey: String) {
        log("onViewDidAppear \(viewControllerKey)")
    }

    func onViewWillDisappear(viewControllerKey: String) {
        log("onViewWillDisappear \(viewControllerKey)")
    }

    func onViewDidDisappear(viewControllerKey: String) {
        log("onViewDidDisappear \(viewControllerKey)")
    }
}
