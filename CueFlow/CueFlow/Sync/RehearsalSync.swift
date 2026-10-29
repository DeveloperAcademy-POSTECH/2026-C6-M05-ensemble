//
//  RehearsalSync.swift
//  CueFlow
//
//  리허설 동기화 모드 (#69). 진행하는 사람이 큐를 넘기면 "지금 장면 · 큐"를 iCloud에 올리고,
//  따라가는 사람은 받아서 같은 장면 · 큐로 넘어간다.
//  공연 폴더 안에 "리허설 위치" 레코드 한 장(공연마다 하나)으로 주고받는다.
//  리허설이 끝나면 의미 없는 값이라 SwiftData(공연 데이터)에는 저장하지 않는다.
//

import CloudKit
import Foundation
import Observation

// 지금 진행 중인 위치
struct RehearsalPosition: Equatable {
    var leaderID: String       // 진행하는 사람의 iCloud 계정 ID
    var leaderName: String
    var sceneID: UUID
    var triggerID: UUID?       // 장면에 큐가 없으면 nil
    var updatedAt: Date
}

@Observable
final class RehearsalSync {
    static let shared = RehearsalSync()

    static let recordType = "RehearsalPosition"

    // "이 공연 위치 올려 줘" → CloudSync가 받아서 바로 올린다 (object = 공연 id)
    static let didChangeNotification = Notification.Name("RehearsalSync.didChange")

    // 진행하던 사람이 앱을 그냥 꺼 버리면 "진행 중"이 계속 남는다 → 이만큼 지난 위치는 끝난 것으로 본다
    private static let staleAfter: TimeInterval = 60 * 60

    // 공연 id → 지금 진행 위치. 진행하는 사람이 없으면 없음
    private var positions: [UUID: RehearsalPosition] = [:]

    // 내가 진행을 끝낸 때. 끝내기 전에 올린 내 위치가 늦게 돌아와도 무시하려고
    private var stoppedAt: [UUID: Date] = [:]

    // 리허설 화면이 열려 있는 공연 → CloudSync가 이 공연의 위치만 자주 확인한다
    var watchingProductionID: UUID?

    func position(of productionID: UUID) -> RehearsalPosition? {
        guard let position = positions[productionID],
              Date.now.timeIntervalSince(position.updatedAt) < Self.staleAfter else { return nil }
        return position
    }

    // MARK: - 진행하는 사람

    // 진행 시작 · 큐 넘길 때마다 부른다
    // TODO: 멤버 역할이 생기면 감독(연출 · 무대감독)만 진행할 수 있게
    func lead(productionID: UUID, leaderID: String, leaderName: String, sceneID: UUID, triggerID: UUID?) {
        #if DEBUG
        fakeSent[productionID] = nil   // 진짜로 진행하면 가짜 진행자는 그만
        #endif
        positions[productionID] = RehearsalPosition(
            leaderID: leaderID, leaderName: leaderName,
            sceneID: sceneID, triggerID: triggerID, updatedAt: .now
        )
        NotificationCenter.default.post(name: Self.didChangeNotification, object: productionID)
    }

    // 진행 끝내기 → 빈 위치를 올려서 다른 사람 화면에서도 "진행 중"이 사라지게
    func stopLeading(productionID: UUID) {
        #if DEBUG
        fakeSent[productionID] = nil
        #endif
        positions[productionID] = nil
        stoppedAt[productionID] = .now
        NotificationCenter.default.post(name: Self.didChangeNotification, object: productionID)
    }

    // MARK: - iCloud 레코드

    // 레코드 이름 = "RehearsalPosition-공연id" (공연마다 하나, 기기가 달라도 같다)
    static func recordName(for productionID: UUID) -> String {
        "\(recordType)-\(productionID.uuidString)"
    }

    static func productionID(fromRecordName name: String) -> UUID? {
        guard name.hasPrefix("\(recordType)-") else { return nil }
        return UUID(uuidString: String(name.dropFirst(recordType.count + 1)))
    }

    // 올릴 때: 지금 위치를 레코드에 채운다. 진행하는 사람이 없으면 진행자 칸을 비운다
    func fill(_ record: CKRecord, productionID: UUID) {
        var position = positions[productionID]
        var endedAt = stoppedAt[productionID]
        #if DEBUG
        if let fake = fakeSent[productionID] {
            position = fake
            endedAt = nil
        }
        #endif
        record[Key.leaderID] = position?.leaderID ?? ""
        record[Key.leaderName] = position?.leaderName ?? ""
        record[Key.sceneID] = position?.sceneID.uuidString ?? ""
        record[Key.triggerID] = position?.triggerID?.uuidString ?? ""
        record[Key.updatedAt] = position?.updatedAt ?? endedAt ?? .now
    }

    // 받았을 때: 진행자 칸이 비어 있으면 진행 끝
    func receive(_ record: CKRecord) {
        guard let productionID = Self.productionID(fromRecordName: record.recordID.recordName) else { return }
        // 지금 가진 것보다 옛날 위치면 무시 (내가 올린 게 되돌아오거나, 늦게 도착한 경우 → 한 칸 뒤로 튀지 않게)
        let recordDate = record[Key.updatedAt] as? Date ?? .distantPast
        if let current = positions[productionID], recordDate < current.updatedAt { return }
        if positions[productionID] == nil, let stopped = stoppedAt[productionID], recordDate < stopped { return }
        guard let leaderID = record[Key.leaderID] as? String, !leaderID.isEmpty,
              let sceneID = (record[Key.sceneID] as? String).flatMap(UUID.init(uuidString:)) else {
            positions[productionID] = nil
            return
        }
        positions[productionID] = RehearsalPosition(
            leaderID: leaderID,
            leaderName: record[Key.leaderName] as? String ?? "",
            sceneID: sceneID,
            triggerID: (record[Key.triggerID] as? String).flatMap(UUID.init(uuidString:)),
            updatedAt: record[Key.updatedAt] as? Date ?? .now
        )
    }

    #if DEBUG
    // MARK: - 개발용 가짜 진행자 (맥 한 대로 "따라가기" 확인)

    // 메뉴 막대 "개발용 → 가짜 진행자"가 보내면 열려 있는 리허설 화면이 받아서 한 칸 움직인다
    static let fakeLeaderNotification = Notification.Name("RehearsalSync.fakeLeader")
    enum FakeStep { case next, previous, stop }

    // 가짜 진행자가 마지막으로 올린 위치. 공연 id → 위치 (nil = 진행 끝을 올림)
    private var fakeSent: [UUID: RehearsalPosition?] = [:]

    // 가짜 진행자가 다음 칸을 셀 기준 (받은 위치는 아직 안 왔을 수 있어서, 마지막으로 올린 것부터)
    func fakeBase(of productionID: UUID) -> RehearsalPosition? {
        fakeSent[productionID] ?? positions[productionID]
    }

    // 다른 사람인 척 iCloud에 실제로 올린다 → 0.5초 확인으로 받아서 따라간다 (맥 한 대로 왕복 시간 확인)
    // 내 화면 위치(positions)는 건드리지 않는다 — iCloud에서 돌아와야 움직여야 하니까. 장면이 nil이면 진행 끝
    func sendFake(productionID: UUID, sceneID: UUID?, triggerID: UUID?) {
        let position = sceneID.map {
            RehearsalPosition(leaderID: "fake-leader", leaderName: "테스트", sceneID: $0, triggerID: triggerID, updatedAt: .now)
        }
        fakeSent.updateValue(position, forKey: productionID)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: productionID)
    }
    #endif

    private enum Key {
        static let leaderID = "leaderID"
        static let leaderName = "leaderName"
        static let sceneID = "sceneID"
        static let triggerID = "triggerID"
        static let updatedAt = "updatedAt"
    }
}
