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

    // 이 맥의 iCloud 로그인 상태 (앱 전체에서 같이 씀)
    @State private var iCloudAccount = ICloudAccount()

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
        // cloudKitDatabase: .none — iCloud를 켜면 SwiftData가 자동으로 내 iCloud에 동기화하려 하는데,
        // 그 방식은 다른 사람과 공유가 안 돼서 끈다. 공유·동기화는 CKSyncEngine으로 따로 한다 (#67)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

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
                .environment(iCloudAccount)
                .task { await iCloudAccount.refresh() }
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
