//
//  CueFlowApp.swift
//  CueFlow
//
//  Created by yunseo on 10/7/26.
//

import SwiftUI
import SwiftData

@main
struct CueFlowApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Production.self,
            Cue.self,
            Part.self,
            ShowScene.self,
            Trigger.self,
            Member.self,
            Comment.self,
            CueCheck.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
