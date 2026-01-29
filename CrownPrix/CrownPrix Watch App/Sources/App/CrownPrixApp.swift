//
//  CrownPrixApp.swift
//  CrownPrix Watch App
//
//  Created by 양시준 on 1/29/26.
//

import SwiftUI

@main
struct CrownPrix_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    GameCenterManager.shared.authenticate()
                }
        }
    }
}
