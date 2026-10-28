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
    // 초대 링크로 앱이 열리면 맥이 여기에 알려 준다 (#68)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // 사이드바 다크모드 스위치가 바꾸는 값
    @AppStorage("isDarkMode") private var isDarkMode = false

    // 이 맥의 iCloud 로그인 상태 (앱 전체에서 같이 씀)
    @State private var iCloudAccount = ICloudAccount()

    // iCloud 주고받기 (#67)
    @State private var cloudSync = CloudSync()

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
                .task {
                    await iCloudAccount.refresh()
                }
                // 앱을 켤 때 로그인돼 있거나, 켜 둔 채로 시스템 설정에서 로그인하면 시작
                // (로그아웃은 CKSyncEngine이 알려 줘서 CloudSync가 직접 멈춘다)
                .onChange(of: iCloudAccount.status) { _, status in
                    if status == .available {
                        cloudSync.start(context: sharedModelContainer.mainContext)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            #if DEBUG
            // 개발용 (TestFlight에는 안 보임)
            CommandMenu("개발용") {
                Button("이 맥 데이터만 지우기 (iCloud에서 다시 받기)") {
                    NotificationCenter.default.post(name: UserTest.didResetNotification, object: nil)
                    cloudSync.resetLocalAndRefetch()
                }
                // 초대 링크 없이 역할 선택 화면 확인 (ContentView가 테스트용 공연을 만들어 띄운다)
                Button("가짜 초대 수락 (역할 선택 화면)") {
                    NotificationCenter.default.post(name: InviteRoleView.fakeAcceptNotification, object: nil)
                }

                // 리허설 동기화 모드(#69) "따라가기"를 맥 한 대로 확인. 리허설 화면이 열려 있을 때만 동작
                Divider()
                Button("가짜 진행자: 시작 · 다음 큐") {
                    NotificationCenter.default.post(name: RehearsalSync.fakeLeaderNotification, object: RehearsalSync.FakeStep.next)
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                Button("가짜 진행자: 이전 큐") {
                    NotificationCenter.default.post(name: RehearsalSync.fakeLeaderNotification, object: RehearsalSync.FakeStep.previous)
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                Button("가짜 진행자: 진행 끝") {
                    NotificationCenter.default.post(name: RehearsalSync.fakeLeaderNotification, object: RehearsalSync.FakeStep.stop)
                }
            }
            #endif

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
