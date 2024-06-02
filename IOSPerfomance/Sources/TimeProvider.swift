//
//  TimeProvider.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 25/01/2022.
//

import Foundation

protocol TimeProvider {
    func now() -> DispatchTime
}

var defaultTimeProvider: TimeProvider = DefaultTimeProvider()

final class DefaultTimeProvider: TimeProvider {
    func now() -> DispatchTime {
        return DispatchTime.now()
    }
}
