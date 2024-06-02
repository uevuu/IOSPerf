//
//  PerformanceScreen.swift
//  PerformanceApp
//
//  Created by Maryin Nikita on 29/04/2024.
//

import Foundation


protocol PerformanceTrackable {
    var performanceScreen: PerformanceScreen? { get }
}

enum PerformanceScreen: String {
    case menu
    case rendering
    case list
}
