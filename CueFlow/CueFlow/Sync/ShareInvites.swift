//
//  ShareInvites.swift
//  CueFlow
//
//  초대 링크를 눌러 앱이 열렸을 때 받은 초대를 잠깐 들고 있는 곳 (#68 2단계).
//  링크 → 맥이 앱을 열고 AppDelegate에 초대 정보(CKShare.Metadata)를 줌 → 여기 넣음 → ContentView가 초대 수락 화면을 띄움.
//  링크로 앱을 열려면 Info.plist의 CKSharingSupported = YES 필요.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
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

    // 카톡 등에서 복사한 초대 링크를 붙여 넣어 참여 (카톡 안 브라우저에선 링크를 눌러도 앱이 안 열려서).
    // 앱이 iCloud에 초대 정보를 직접 물어본다 → 받으면 링크로 열렸을 때와 같은 초대 수락 화면.
    // 실패하면 사람이 읽을 이유를 돌려준다 (성공이면 nil)
    func join(link: String) async -> String? {
        // 카톡 메시지를 통째로 복사해도 되게, 글 안에서 iCloud 링크만 찾는다
        guard let url = Self.iCloudLink(in: link) else {
            return "iCloud 초대 링크가 아니에요. 공유하기 창의 [링크 복사]로 받은 링크를 붙여 넣어 주세요."
        }
        do {
            let metadata = try await CKContainer(identifier: ICloudAccount.containerID).shareMetadata(for: url)
            if metadata.participantRole == .owner {
                return "내가 만든 공연의 링크예요. 이미 홈에 있어요."
            }
            receive(metadata)
            return nil
        } catch let error as CKError {
            print("초대 링크 확인 실패: \(error)")   // 원인 찾기용 (Xcode 콘솔)
            return Self.reason(for: error)
        } catch {
            print("초대 링크 확인 실패: \(error)")
            return "초대를 확인하지 못했어요. (\(error.localizedDescription))"
        }
    }

    private static func iCloudLink(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range)
            .compactMap(\.url)
            .first { $0.host?.hasSuffix("icloud.com") == true && $0.path.hasPrefix("/share") }
    }

    private static func reason(for error: CKError) -> String {
        let detail = "(CKError \(error.code.rawValue): \(error.localizedDescription))"
        switch error.code {
        case .unknownItem, .zoneNotFound:
            return "공유가 없어졌어요. 보낸 사람에게 새 링크를 받아 주세요.\n\(detail)"
        case .notAuthenticated:
            return "이 기기에 iCloud 로그인이 안 되어 있어요. 설정에서 로그인해 주세요.\n\(detail)"
        case .permissionFailure:
            return "이 링크를 열 권한이 없어요.\n\(detail)"
        case .networkUnavailable, .networkFailure:
            return "인터넷 연결을 확인해 주세요.\n\(detail)"
        default:
            return "초대를 확인하지 못했어요.\n\(detail)"
        }
    }
}

#if os(macOS)
// 맥이 "초대 링크로 앱 열림"을 알려 주는 곳
final class AppDelegate: NSObject, NSApplicationDelegate {
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
#else
// 아이패드: 앱 시작 · iCloud 알림 신청은 여기, 초대 링크는 화면(Scene) 쪽으로 온다
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        SystemNotifications.shared.start()
        return true
    }

    // 초대 링크를 받을 SceneDelegate를 연결
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

// 아이패드가 "초대 링크로 앱 열림"을 알려 주는 곳
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    // 앱이 꺼져 있다가 링크로 켜졌을 때
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let metadata = connectionOptions.cloudKitShareMetadata else { return }
        Task { @MainActor in
            ShareInvites.shared.receive(metadata)
        }
    }

    // 앱이 켜져 있을 때
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Task { @MainActor in
            ShareInvites.shared.receive(metadata)
        }
    }
}
#endif
