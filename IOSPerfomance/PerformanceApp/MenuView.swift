//
//  MenuView.swift
//  PerformanceApp
//
//  Created by Maryin Nikita on 29/04/2024.
//

import SwiftUI

struct MenuView: View {
    var body: some View {
        List {
            Section(header: Text("Зависания")) {
                Text("Не фатальные").onTapGesture {
                    IssuesSimulator.simulateNonFatalHang()
                }

                Text("Фатальные").onTapGesture {
                    IssuesSimulator.simulateFatalHang()
                }
            }

            Section(header: Text("Метрики")) {
                let ttiMode = ListMode("1", delayInterval: 1, popOnAppear: true)
                NavigationLink(destination: ListView(mode: ttiMode)) {
                    Text("TTI")
                }
            }
        }
    }
}

extension MenuView: PerformanceTrackable {
    var performanceScreen: PerformanceScreen? {
        return .menu
    }
}
