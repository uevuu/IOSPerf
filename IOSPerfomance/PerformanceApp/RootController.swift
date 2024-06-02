//
//  RootView.swift
//  PerformanceApp
//
//  Created by Maryin Nikita on 01/12/2021.
//

import SwiftUI

class RootController: UIHostingController<MenuView> {
    init() {
        super.init(rootView: MenuView())
        self.title = "Metrics"

        Thread.sleep(forTimeInterval: 2)
    }

    @MainActor @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
