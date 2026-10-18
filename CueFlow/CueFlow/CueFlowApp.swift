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
    // 사이드바 다크모드 스위치가 바꾸는 값
    @AppStorage("isDarkMode") private var isDarkMode = false

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
            StagePlacement.self,
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
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            // UT 진행자용 메뉴 (TestFlight에도 보임). UserTest.hidesUnfinished를 false로 바꾸면 사라진다
            if UserTest.hidesUnfinished {
                CommandMenu("UT 진행") {
                    Button("예시 공연 넣기 (레미제라블)") {
                        UserTest.insertSample(into: sharedModelContainer.mainContext)
                    }

                    Divider()

                    // 참가자가 바뀔 때: 저장된 공연을 전부 지우고 빈 홈 화면으로
                    Button("모든 데이터 지우기") {
                        UserTest.deleteAll(in: sharedModelContainer.mainContext)
                    }
                }
            }
        }
    }
}
