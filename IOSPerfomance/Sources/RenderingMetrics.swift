//
//  RenderingMetrics.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 26/01/2022.
//

import Foundation

/// Continuous data that we gather about the rendering performance
public struct RenderingMetrics: CustomStringConvertible, Equatable {

    private static let slowFrameThreshold: CFTimeInterval = 0.017
    private static let frozenFrameThreshold: CFTimeInterval = 0.7
    static let refreshRateDurationThreshold: CFTimeInterval = 0.001

    public let renderedFrames: Int

    public let expectedFrames: Int
   
    public let droppedFrames: Int

    public let frozenFrames: Int

    public let slowFrames: Int

    public let freezeTime: DispatchTimeInterval

    public let sessionDuration: DispatchTimeInterval

    public let appStartInfo: AppStartInfo

    public var frozenFramesRatio: Decimal? {
        guard renderedFrames > 0 else {
            return nil
        }
        return Decimal(frozenFrames) / Decimal(renderedFrames)
    }

    public var slowFramesRatio: Decimal? {
        guard renderedFrames > 0 else {
            return nil
        }
        return Decimal(slowFrames) / Decimal(renderedFrames)
    }

    public var droppedFramesRatio: Decimal? {
        guard expectedFrames > 0 else {
            return nil
        }
        return Decimal(droppedFrames) / Decimal(expectedFrames)
    }


    public static var zero: Self {
        return RenderingMetrics(
            renderedFrames: 0,
            expectedFrames: 0,
            droppedFrames: 0,
            frozenFrames: 0,
            slowFrames: 0,
            freezeTime: .zero,
            sessionDuration: .zero,
            appStartInfo: .empty
        )
    }

    public var description: String {
        return
            "renderedFrames: \(renderedFrames), expectedFrames: \(expectedFrames), droppedFrames: \(droppedFrames), freezeTime: \(freezeTime.milliseconds ?? 0) ms, sessionDuration: \(sessionDuration.timeInterval ?? 0) seconds"
    }

    static func metrics(frameDuration: CFTimeInterval, refreshRateDuration: CFTimeInterval) -> Self {
        let renderedFrames = 1
        let frozenFrames = frameDuration >= frozenFrameThreshold ? 1 : 0
        let slowFrames = frameDuration >= slowFrameThreshold ? 1 : 0
        let expectedFrames: Int
        let droppedFrames: Int
        if frameDuration > (refreshRateDuration + refreshRateDurationThreshold) {
            expectedFrames = Int(round(frameDuration / refreshRateDuration))
            droppedFrames = expectedFrames - 1
        } else {
            expectedFrames = 1
            droppedFrames = 0
        }

        let currentFreezeTime = frameDuration - refreshRateDuration
        let freezeTime = DispatchTimeInterval.timeInterval(currentFreezeTime)
        let sessionDuration = DispatchTimeInterval.timeInterval(frameDuration)

        return RenderingMetrics(
            renderedFrames: renderedFrames,
            expectedFrames: expectedFrames,
            droppedFrames: droppedFrames,
            frozenFrames: frozenFrames,
            slowFrames: slowFrames,
            freezeTime: freezeTime,
            sessionDuration: sessionDuration,
            appStartInfo: AppInfoHolder.appStartInfo)
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        if rhs == .zero {
            return lhs
        }
        if lhs == .zero {
            return rhs
        }
        return RenderingMetrics(
            renderedFrames: lhs.renderedFrames + rhs.renderedFrames,
            expectedFrames: lhs.expectedFrames + rhs.expectedFrames,
            droppedFrames: lhs.droppedFrames + rhs.droppedFrames,
            frozenFrames: lhs.frozenFrames + rhs.frozenFrames,
            slowFrames: lhs.slowFrames + rhs.slowFrames,
            freezeTime: lhs.freezeTime + rhs.freezeTime,
            sessionDuration: lhs.sessionDuration + rhs.sessionDuration,
            appStartInfo: AppStartInfo.merge(lhs.appStartInfo, rhs.appStartInfo)
        )
    }
}
