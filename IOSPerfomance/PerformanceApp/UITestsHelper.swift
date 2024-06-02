//
//  UITestsHelper.swift
//  PerformanceSuite-PerformanceApp
//
//  Created by Maryin Nikita on 19/12/2024.
//

import Foundation

class UITestsHelper {
    static func prepareForTestsIfNeeded() {
        if shouldClearStorage {
            clearStorage()
        }
    }

    static let isInTests = ProcessInfo.processInfo.environment[inTestsKey] != nil
    private static let shouldClearStorage = ProcessInfo.processInfo.environment[clearStorageKey] != nil

    private static func clearStorage() {
        guard let domain = Bundle.main.bundleIdentifier else {
            fatalError("no bundle identifier")
        }
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.resetStandardUserDefaults()
    }
}
