//
//  CrashesInterceptor.swift
//  PerformanceApp
//
//  Created by Maryin Nikita on 29/04/2024.
//

import Foundation


class CrashesInterceptor {
    static func interceptCrashes() {
        UserDefaults.standard.removeObject(forKey: key)

        signal(SIGTRAP) { s in
            debugPrint("Crash intercepted")
            UserDefaults.standard.set(true, forKey: key)
            UserDefaults.standard.synchronize()
            exit(s)
        }
    }

    static func didCrashDuringPreviousLaunch() -> Bool {
        return UserDefaults.standard.bool(forKey: key)
    }
}

private let key = "app_did_crash"
