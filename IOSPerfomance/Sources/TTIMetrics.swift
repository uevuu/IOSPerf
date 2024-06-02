//
//  TTIMetrics.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 26/01/2022.
//

import Foundation

public struct TTIMetrics: CustomStringConvertible, Equatable {

    public let tti: DispatchTimeInterval

    public let ttfr: DispatchTimeInterval

    public let appStartInfo: AppStartInfo

    public var description: String {
        return "tti: \(tti.milliseconds ?? 0) ms, ttfr: \(ttfr.milliseconds ?? 0) ms"
    }
}
