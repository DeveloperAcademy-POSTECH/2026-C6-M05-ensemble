//
//  SystemNotifications.swift
//  CueFlow
//
//  맥 시스템 알림 (#103 · 피그마 951:11334 전체공지 / 951:11335 큐 수정).
//  다른 사람이 보낸 새 공지 · 내 파트 큐 수정이 iCloud로 오면 화면 오른쪽 위 알림으로 띄운다.
//  CloudSync가 받은 걸 보고 띄우는 방식이라 앱이 켜져 있을 때만 뜬다 (Dock에 있어도 됨).
//  알림을 누르면 그 공지 / 그 공연 큐시트로 (ContentView).
//

import AppKit
import UserNotifications

final class SystemNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = SystemNotifications()

    // 알림을 눌렀을 때 → ContentView가 그 화면을 연다. object = Target
    static let openNotification = Notification.Name("SystemNotifications.open")

    #if DEBUG
    // 메뉴 막대 "개발용 → 가짜 새 공지 / 가짜 큐 수정" → ContentView가 알림을 띄운다
    static let fakeNoticeNotification = Notification.Name("SystemNotifications.fakeNotice")
    static let fakeCueChangeNotification = Notification.Name("SystemNotifications.fakeCueChange")
    #endif

    enum Target {
        case notice(UUID)
        case production(UUID)
    }

    // 큐 수정은 바로 띄우지 않고 고치는 게 30초 멈출 때까지 모았다가 공연 · 파트마다 하나로 요약한다.
    // 알림 센터에 아직 안 본 같은 알림이 있으면 쌓지 않고 그 알림 내용을 바꾼다 (지금까지 고친 것 전부로)
    private struct CueBatch {
        let production: Production
        let part: Part
        var pendingCueIDs: Set<UUID> = []   // 아직 안 띄운 것
        var shownCueIDs: Set<UUID> = []     // 지금 떠 있는 알림에 들어간 것
        var shownSceneIDs: Set<UUID> = []
        var pendingSceneIDs: Set<UUID> = []
        var flushTask: Task<Void, Never>?
    }
    private var cueBatches: [String: CueBatch] = [:]
    private let cueBatchDelay: Duration = .seconds(30)

    private let center = UNUserNotificationCenter.current()

    // 앱 켤 때 한 번: 처음이면 맥이 "알림 허용?" 창을 띄운다
    func start() {
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // 제목 "전체공지 · 레미제라블" / 부제목 = 공지 제목 / 내용 = 공지 앞부분 (길면 맥이 자름)
    func notifyNotice(_ notice: Notice) {
        let content = UNMutableNotificationContent()
        content.title = notice.productionTitle.isEmpty ? notice.targetTag : "\(notice.targetTag) · \(notice.productionTitle)"
        content.subtitle = notice.title
        content.body = notice.body
        content.sound = .default
        content.userInfo = ["notice": notice.id.uuidString]
        add(id: "notice-\(notice.id.uuidString)", content: content)
    }

    // 큐 수정을 모은다. 30초 동안 더 안 오면 공연 · 파트마다 알림 하나
    func notifyCueChanges(_ cues: [Cue]) {
        for cue in cues {
            guard let part = cue.part, let scene = cue.trigger?.scene, let production = scene.production else { continue }
            let key = "\(production.id.uuidString)-\(part.id.uuidString)"
            var batch = cueBatches[key] ?? CueBatch(production: production, part: part)
            batch.pendingCueIDs.insert(cue.id)
            batch.pendingSceneIDs.insert(scene.id)
            batch.flushTask?.cancel()
            batch.flushTask = Task { [weak self, cueBatchDelay] in
                try? await Task.sleep(for: cueBatchDelay)
                guard !Task.isCancelled else { return }
                await self?.flushCueBatch(key)
            }
            cueBatches[key] = batch
        }
    }

    // 1개 장면: "무대팀 S#1 지금 수정되었습니다" (피그마 문구)
    // 여러 장면: "무대팀 S#1 · S#3 외 2개 장면에서 큐 12개가 수정되었습니다"
    private func flushCueBatch(_ key: String) async {
        guard var batch = cueBatches[key] else { return }
        let id = "cue-\(key)"

        // 떠 있던 알림을 이미 눌렀거나 지웠으면 처음부터 다시 센다
        let delivered = await center.deliveredNotifications()
        if !delivered.contains(where: { $0.request.identifier == id }) {
            batch.shownCueIDs = []
            batch.shownSceneIDs = []
        }
        batch.shownCueIDs.formUnion(batch.pendingCueIDs)
        batch.shownSceneIDs.formUnion(batch.pendingSceneIDs)
        batch.pendingCueIDs = []
        batch.pendingSceneIDs = []
        batch.flushTask = nil
        cueBatches[key] = batch

        let allScenes = (batch.production.scenes ?? []).sorted { $0.order < $1.order }
        let codes = allScenes.filter { batch.shownSceneIDs.contains($0.id) }.map { $0.code(in: allScenes) }
        guard let first = codes.first else { return }
        let teamName = "\(batch.part.name)팀"

        let content = UNMutableNotificationContent()
        content.title = "알림"
        if codes.count == 1 {
            content.body = "\(teamName) \(first) 지금 수정되었습니다"
        } else {
            let shown = codes.prefix(2).joined(separator: " · ")
            let more = codes.count > 2 ? " 외 \(codes.count - 2)개 장면" : ""
            content.body = "\(teamName) \(shown)\(more)에서 큐 \(batch.shownCueIDs.count)개가 수정되었습니다"
        }
        content.sound = .default
        content.userInfo = ["production": batch.production.id.uuidString]
        add(id: id, content: content)
    }

    private func add(id: String, content: UNNotificationContent) {
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    // 앱을 보고 있을 때도 알림을 띄운다 (안 그러면 맥이 숨김)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    // 알림을 누르면 앱을 앞으로 + 그 공지 / 공연으로
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let target: Target?
        if let id = (info["notice"] as? String).flatMap(UUID.init(uuidString:)) {
            target = .notice(id)
        } else if let id = (info["production"] as? String).flatMap(UUID.init(uuidString:)) {
            target = .production(id)
        } else {
            target = nil
        }
        await MainActor.run {
            NSApp.activate()
            if let target {
                NotificationCenter.default.post(name: Self.openNotification, object: target)
            }
        }
    }
}
