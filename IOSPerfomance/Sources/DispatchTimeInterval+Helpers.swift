//
//  DispatchTimeInterval+Helpers.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 07/07/2021.
//

import Foundation

public extension DispatchTimeInterval {


    static var zero: DispatchTimeInterval {
        return .seconds(0)
    }

    var timeInterval: TimeInterval? {
        switch self {
        case let .seconds(seconds):
            return TimeInterval(seconds)
        case let .milliseconds(milliseconds):
            return TimeInterval(milliseconds) / 1000
        case let .microseconds(microseconds):
            return TimeInterval(microseconds) / 1000_000
        case let .nanoseconds(nanoseconds):
            return TimeInterval(nanoseconds) / 1000_000_000
        case .never:
            return nil
        @unknown default:
            return nil
        }
    }

   
    var seconds: Int? {
        switch self {
        case let .seconds(seconds):
            return seconds
        case let .milliseconds(milliseconds):
            return milliseconds / 1000
        case let .microseconds(microseconds):
            return microseconds / 1000_000
        case let .nanoseconds(nanoseconds):
            return nanoseconds / 1000_000_000
        case .never:
            return nil
        @unknown default:
            return nil
        }
    }

   
    var milliseconds: Int? {
        switch self {
        case let .seconds(seconds):
            return handleOverflow(seconds.multipliedReportingOverflow(by: 1000))
        case let .milliseconds(milliseconds):
            return milliseconds
        case let .microseconds(microseconds):
            return microseconds / 1000
        case let .nanoseconds(nanoseconds):
            return nanoseconds / 1000_000
        case .never:
            return nil
        @unknown default:
            return nil
        }
    }

    /// Helper method to get Int number of milliseconds from `DispatchTimeInterval`.
    ///
    /// Use it if you don't need microseconds precision.
    ///
    /// ## Caution!
    /// Number of microseconds may not fit into `Int` if we have large amount of seconds in the enum. We return `nil` in this case.
    var microseconds: Int? {
        switch self {
        case let .seconds(seconds):
            return handleOverflow(seconds.multipliedReportingOverflow(by: 1000_000))
        case let .milliseconds(milliseconds):
            return handleOverflow(milliseconds.multipliedReportingOverflow(by: 1000))
        case let .microseconds(microseconds):
            return microseconds
        case let .nanoseconds(nanoseconds):
            return nanoseconds / 1000
        case .never:
            return nil
        @unknown default:
            return nil
        }
    }

   
    var nanoseconds: Int? {
        switch self {
        case let .seconds(seconds):
            return handleOverflow(seconds.multipliedReportingOverflow(by: 1000_000_000))
        case let .milliseconds(milliseconds):
            return handleOverflow(milliseconds.multipliedReportingOverflow(by: 1000_000))
        case let .microseconds(microseconds):
            return handleOverflow(microseconds.multipliedReportingOverflow(by: 1000))
        case let .nanoseconds(nanoseconds):
            return nanoseconds
        case .never:
            return nil
        @unknown default:
            return nil
        }
    }

    static func timeInterval(_ interval: TimeInterval) -> DispatchTimeInterval {
        if let nanoseconds = Int(exactly: floor(interval * 1_000_000_000)) {
            return .nanoseconds(nanoseconds)
        } else if let microseconds = Int(exactly: floor(interval * 1_000_000)) {
            return .microseconds(microseconds)
        } else if let milliseconds = Int(exactly: floor(interval * 1_000)) {
            return .milliseconds(milliseconds)
        } else if let seconds = Int(exactly: floor(interval)) {
            return .seconds(seconds)
        } else {
            return .never
        }
    }

    private static func tryPrecision(lhs: DispatchTimeInterval, rhs: DispatchTimeInterval, precision: KeyPath<DispatchTimeInterval, Int?>, result: (Int) -> DispatchTimeInterval) -> DispatchTimeInterval? {
        guard let llhs = lhs[keyPath: precision], let rrhs = rhs[keyPath: precision] else {
            return nil
        }

        guard let resultValue = handleOverflow(llhs.addingReportingOverflow(rrhs)) else {
            return nil
        }
        return result(resultValue)
    }

    private static func sumUsingTheBestPrecision(lhs: DispatchTimeInterval, rhs: DispatchTimeInterval, precision: DispatchTimeInterval)
    -> DispatchTimeInterval {
        var (tryNanoseconds, tryMicroseconds, tryMilliseconds, trySeconds) = (false, false, false, false)
        switch precision {
        case .nanoseconds:
            (tryNanoseconds, tryMicroseconds, tryMilliseconds, trySeconds) = (true, true, true, true)
        case .microseconds:
            (tryMicroseconds, tryMilliseconds, trySeconds) = (true, true, true)
        case .milliseconds:
            (tryMilliseconds, trySeconds) = (true, true)
        case .seconds:
            trySeconds = true
        case .never:
            break
        @unknown default:
            break
        }

        if tryNanoseconds, let result = tryPrecision(lhs: lhs, rhs: rhs, precision: \.nanoseconds, result: DispatchTimeInterval.nanoseconds) {
            return result
        }

        if tryMicroseconds, let result = tryPrecision(lhs: lhs, rhs: rhs, precision: \.microseconds, result: DispatchTimeInterval.microseconds) {
            return result
        }

        if tryMilliseconds, let result = tryPrecision(lhs: lhs, rhs: rhs, precision: \.milliseconds, result: DispatchTimeInterval.milliseconds) {
            return result
        }

        if trySeconds, let result = tryPrecision(lhs: lhs, rhs: rhs, precision: \.seconds, result: DispatchTimeInterval.seconds) {
            return result
        }

        return .never
    }

    static func + (_ lhs: DispatchTimeInterval, _ rhs: DispatchTimeInterval) -> DispatchTimeInterval {

        switch (lhs, rhs) {
        case (.never, _), (_, .never):
            return .never
        case let (.nanoseconds(llhs), .nanoseconds(rrhs)):
            return .nanoseconds(llhs + rrhs)
        case let (.microseconds(llhs), .microseconds(rrhs)):
            return .microseconds(llhs + rrhs)
        case let (.milliseconds(llhs), .milliseconds(rrhs)):
            return .milliseconds(llhs + rrhs)
        case let (.seconds(llhs), .seconds(rrhs)):
            return .seconds(llhs + rrhs)
            
        case (.nanoseconds, _), (_, .nanoseconds):
            return sumUsingTheBestPrecision(lhs: lhs, rhs: rhs, precision: .nanoseconds(0))
        case (.microseconds, _), (_, .microseconds):
            return sumUsingTheBestPrecision(lhs: lhs, rhs: rhs, precision: .microseconds(0))
        case (.milliseconds, _), (_, .milliseconds):
            return sumUsingTheBestPrecision(lhs: lhs, rhs: rhs, precision: .milliseconds(0))
        case (.seconds, _), (_, .seconds):
            return sumUsingTheBestPrecision(lhs: lhs, rhs: rhs, precision: .nanoseconds(0))
        default:
            return .never
        }
    }

    static func > (_ lhs: DispatchTimeInterval, _ rhs: DispatchTimeInterval) -> Bool {
        if lhs == rhs {
            return false
        }

        if let llhs = lhs.nanoseconds, let rrhs = rhs.nanoseconds {
            return llhs > rrhs
        }
        if let llhs = lhs.microseconds, let rrhs = rhs.microseconds {
            return llhs > rrhs
        }
        if let llhs = lhs.milliseconds, let rrhs = rhs.milliseconds {
            return llhs > rrhs
        }
        if let llhs = lhs.seconds, let rrhs = rhs.seconds {
            return llhs > rrhs
        }
        return false
    }

    static func < (_ lhs: DispatchTimeInterval, _ rhs: DispatchTimeInterval) -> Bool {
        if lhs == rhs {
            return false
        }

        return !(lhs > rhs)
    }
}

private func handleOverflow(_ tuple: (partialValue: Int, overflow: Bool)) -> Int? {
    if tuple.overflow {
        return nil
    }

    return tuple.partialValue
}
