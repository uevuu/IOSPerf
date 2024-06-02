//
//  HangInfo.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 13/09/2022.
//

import Foundation
import MachO
import UIKit


#if canImport(MainThreadCallStack)
import MainThreadCallStack
#endif

public struct HangInfo: Codable {

    public let callStack: String

    public let architecture: String

    public let iOSVersion: String

    public let appStartInfo: AppStartInfo

    public let appRuntimeInfo: AppRuntimeInfo


    public let duringStartup: Bool

    private var durationInMilliseconds: Int

    public internal(set) var duration: DispatchTimeInterval {
        get {
            return .milliseconds(durationInMilliseconds)
        }
        set {
            durationInMilliseconds = newValue.milliseconds ?? 0
        }
    }

    init(
        callStack: String,
        architecture: String,
        iOSVersion: String,
        appStartInfo: AppStartInfo,
        appRuntimeInfo: AppRuntimeInfo,
        duringStartup: Bool,
        duration: DispatchTimeInterval
    ) {
        self.callStack = callStack
        self.architecture = architecture
        self.iOSVersion = iOSVersion
        self.appStartInfo = appStartInfo
        self.appRuntimeInfo = appRuntimeInfo
        self.duringStartup = duringStartup
        self.durationInMilliseconds = duration.milliseconds ?? 0
    }

    public static func with(callStack: String, duringStartup: Bool, duration: DispatchTimeInterval) -> HangInfo {
        return HangInfo(
            callStack: callStack,
            architecture: currentArchitecture ?? unknownKeyword,
            iOSVersion: currentIOSVersion,
            appStartInfo: AppInfoHolder.appStartInfo,
            appRuntimeInfo: AppInfoHolder.appRuntimeInfo,
            duringStartup: duringStartup,
            duration: duration)
    }


    private static let currentArchitecture: String? = {
        #if swift(>=5.9)
        if #available(iOS 16, *) {
            if let archName = macho_arch_name_for_mach_header_reexported() {
                return String(cString: archName)
            }
        } else {
            let info = NXGetLocalArchInfo()
            if let name = info?.pointee.name {
                return String(cString: name)
            }
        }
        #else
        let info = NXGetLocalArchInfo()
        if let name = info?.pointee.name {
            return String(cString: name)
        }
        #endif
        return nil
    }()

    private static var currentIOSVersion: String {
        return UIDevice.current.systemVersion
    }
}
