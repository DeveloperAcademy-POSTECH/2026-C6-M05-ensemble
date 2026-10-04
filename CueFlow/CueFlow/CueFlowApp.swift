//
//  CueFlowApp.swift
//  CueFlow
//
//  Created by yunseo on 10/4/26.
//

import SwiftUI

@main
struct CueFlowApp: App {
    @State private var store = CueStore.sample()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
