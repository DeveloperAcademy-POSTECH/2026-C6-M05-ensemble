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
            ScriptLine.self,
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
        #if DEBUG
        .commands {
            // 개발할 때만 보이는 메뉴 (TestFlight · 출시 앱에는 없음)
            CommandMenu("개발용") {
                Button("예시 공연 넣기 (레미제라블)") {
                    let production = RehearsalPreviewData.production
                    production.scenes?.forEach { $0.scriptLines = [] }   // 대본 입력을 시험해 볼 수 있게 대본은 비워 둔다
                    sharedModelContainer.mainContext.insert(production)
                }
            }
        }
        #endif
    }
}
