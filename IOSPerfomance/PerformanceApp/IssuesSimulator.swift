//
//  IssuesSimulator.swift
//  PerformanceApp
//
//  Created by Maryin Nikita on 29/04/2024.
//

import Foundation

class IssuesSimulator {
    static func simulateNonFatalHang() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            Thread.sleep(forTimeInterval: 4.5)
        }
    }

    static func simulateFatalHang() {
        let lock = NSLock()
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500)) {
            lock.lock()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(700)) {
                lock.lock()
            }
        }
    }

    static func simulateWatchdogTermination() {
        exit(0)
    }

    static func simulateCrash() {
        let a = 4
        let b = Int.random(in: 0...1) * (a - 4)
        let c = a / b
        print("Will not be executed \(c)")
    }
}
