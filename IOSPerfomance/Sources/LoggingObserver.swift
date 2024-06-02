//
//  LoggingObserver.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 23/09/2022.
//

import Foundation
import UIKit
import SwiftUI

public protocol ViewControllerLoggingReceiver: AnyObject {

    func key(for viewController: UIViewController) -> String

    func onInit(viewControllerKey: String)

    func onViewDidLoad(viewControllerKey: String)

    func onViewWillAppear(viewControllerKey: String)

    func onViewDidAppear(viewControllerKey: String)

    func onViewWillDisappear(viewControllerKey: String)

    func onViewDidDisappear(viewControllerKey: String)
}


final class LoggingObserver: ViewControllerObserver {

    init(receiver: ViewControllerLoggingReceiver) {
        self.receiver = receiver
    }

    private var receiver: ViewControllerLoggingReceiver?

    func beforeInit(viewController: UIViewController) {
        guard let key = self.receiver?.key(for: viewController) else {
            return
        }
        PerformanceMonitoring.consumerQueue.async {
            self.receiver?.onInit(viewControllerKey: key)
        }
    }

    func beforeViewDidLoad(viewController: UIViewController) {
        guard let key = self.receiver?.key(for: viewController) else {
            return
        }
        PerformanceMonitoring.consumerQueue.async {
            self.receiver?.onViewDidLoad(viewControllerKey: key)
        }
    }

    func afterViewWillAppear(viewController: UIViewController) {
        guard let key = self.receiver?.key(for: viewController) else {
            return
        }
        PerformanceMonitoring.consumerQueue.async {
            self.receiver?.onViewWillAppear(viewControllerKey: key)
        }
    }

    func afterViewDidAppear(viewController: UIViewController) {
        guard let key = self.receiver?.key(for: viewController) else {
            return
        }
        rememberOpenedScreenIfNeeded(viewController)
        PerformanceMonitoring.consumerQueue.async {
            self.receiver?.onViewDidAppear(viewControllerKey: key)
        }
    }

    func beforeViewWillDisappear(viewController: UIViewController) {
        guard let key = self.receiver?.key(for: viewController) else {
            return
        }
        PerformanceMonitoring.consumerQueue.async {
            self.receiver?.onViewWillDisappear(viewControllerKey: key)
        }
    }

    func beforeViewDidDisappear(viewController: UIViewController) {
        guard let key = self.receiver?.key(for: viewController) else {
            return
        }
        PerformanceMonitoring.consumerQueue.async {
            self.receiver?.onViewDidDisappear(viewControllerKey: key)
        }
    }

    // MARK: - Top screen detection

    private func rememberOpenedScreenIfNeeded(_ viewController: UIViewController) {
        guard isTopScreen(viewController) else {
            return
        }
        let description = RootViewIntrospection.shared.description(viewController: viewController)
        AppInfoHolder.screenOpened(description)
    }

    private func isTopScreen(_ viewController: UIViewController) -> Bool {
        assert(Thread.isMainThread)

t
        if isContainerController(viewController) {
            return false
        }

        if let parent = viewController.parent {
            if !isContainerController(parent) {
                return false
            }
        }


        if isUIKitController(viewController) {
            return false
        }

l
        if isCellSubview(viewController.view) || isCellSubview(viewController.view.superview) {
            return false
        }


        if isNavigationBarSubview(viewController.view) {
            return false
        }

        return true
    }

    private func isUIKitController(_ viewController: UIViewController) -> Bool {,
        if viewController is HostingControllerIdentifier {
            return false
        }
        let viewControllerBundle = Bundle(for: type(of: viewController))
        return viewControllerBundle == uiKitBundle
    }

    private func isContainerController(_ viewController: UIViewController) -> Bool {
        let vcType = type(of: viewController)
        return uiKitContainers.contains {
            vcType.isSubclass(of: $0)
        }
    }

    private func isCellSubview(_ view: UIView?) -> Bool {
        guard let view = view else {
            return false
        }

        if view.superview is UITableViewCell {
            return true
        }

        return false
    }

    private func isNavigationBarSubview(_ view: UIView?) -> Bool {
        if view == nil {
            return false
        }

        if view is UINavigationBar {
            return true
        }

        return isNavigationBarSubview(view?.superview)
    }

    private lazy var uiKitBundle = Bundle(for: UIViewController.self)
    private lazy var uiKitContainers = [
        UINavigationController.self,
        UITabBarController.self,
        UISplitViewController.self,
        UIPageViewController.self,
    ]

}

protocol HostingControllerIdentifier { }
extension UIHostingController: HostingControllerIdentifier { }
