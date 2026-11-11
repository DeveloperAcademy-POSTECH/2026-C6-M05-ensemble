//
//  ShareInvites.swift
//  CueFlow
//
//  초대 링크를 눌러 앱이 열렸을 때 받은 초대를 잠깐 들고 있는 곳 (#68 2단계).
//  링크 → 맥이 앱을 열고 AppDelegate에 초대 정보(CKShare.Metadata)를 줌 → 여기 넣음 → ContentView가 초대 수락 화면을 띄움.
//  링크로 앱을 열려면 Info.plist의 CKSharingSupported = YES 필요.
//

import AppKit
import CloudKit
import Observation

@MainActor
@Observable
final class ShareInvites {
    static let shared = ShareInvites()

    // 수락 기다리는 초대. nil이면 없음
    var pending: PendingInvite?

    func receive(_ metadata: CKShare.Metadata) {
        // 내가 만든 공유의 링크를 내가 누른 경우 → 초대가 아니라서 무시
        guard metadata.participantRole != .owner else { return }
        let title = metadata.share[CKShare.SystemFieldKey.title] as? String ?? "공연"
        pending = PendingInvite(productionTitle: title, metadata: metadata)
    }
}

// 맥이 "초대 링크로 앱 열림"을 알려 주는 곳
final class AppDelegate: NSObject, NSApplicationDelegate {
    // 창 탭 기능 끄기 → 보기 메뉴의 "탭 막대 보기 · 모든 탭 보기"가 빠진다 (창이 뜨기 전에 해야 함)
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        CommentShortcut.start()   // 보기 > 댓글 표시 ⇧C를 한글 입력 상태에서도 받기 (AppMenuCommands.swift)
        TextEditingWatcher.shared.start()   // 편집 메뉴: 입력칸에 커서가 있는지 지켜보기 (AppMenuCommands.swift)
    }

    // iCloud 알림(푸시)을 받겠다고 맥에 신청 → 다른 사람이 고치면 CKSyncEngine이 바로 받아 온다
    // (맥 앱은 이걸 직접 신청해야 알림이 온다)
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.registerForRemoteNotifications()
        SystemNotifications.shared.start()   // 새 공지 · 큐 수정 시스템 알림 (#103)
    }

    func application(_ application: NSApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Task { @MainActor in
            ShareInvites.shared.receive(metadata)
        }
    }
}
