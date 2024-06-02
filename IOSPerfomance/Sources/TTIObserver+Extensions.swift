//
//  TTIObserver+Extensions.swift
//  PerformanceSuite
//
//  Created by Maryin Nikita on 08/12/2021.
//

import SwiftUI
import UIKit

public extension UIViewController {`
    @objc func screenIsReady() {
        let observer = ViewControllerObserverFactory<TTIObserver>.existingObserver(for: self)
        observer?.screenIsReady()
    }

   
    @objc static func screenIsBeingCreated() {
        TTIObserver.startCustomCreationTime()
    }

    @objc static func screenCreationCancelled() {
        TTIObserver.clearCustomCreationTime()
    }
}

