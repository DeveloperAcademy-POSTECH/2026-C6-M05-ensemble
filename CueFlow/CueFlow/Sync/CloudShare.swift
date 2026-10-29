//
//  CloudShare.swift
//  CueFlow
//
//  공연 공유(CKShare) — 공연 폴더(레코드 존)를 통째로 공유하고 초대 링크를 만든다 (#68).
//  팀 결정: 공연에 들어온 사람 누구나 초대할 수 있고, 초대받은 사람도 편집할 수 있다
//  → 링크가 있는 사람은 누구나 "편집 가능"으로 참여.
//  우리 앱엔 서버가 없어서 초대 메일은 iCloud가 아니라 이 맥의 메일 앱으로 보낸다 (SharePopover).
//  공유받은 공연은 공유 저장공간(sharedCloudDatabase)에 있어서, 거기서도 다시 초대할 수 있다.
//

import CloudKit
import SwiftData

enum CloudShare {
    // 초대를 수락하면 보낸다 → CloudSync가 공유받은 공연을 바로 받아 온다
    static let didAcceptNotification = Notification.Name("CloudShare.didAccept")

    private static var container: CKContainer { CKContainer(identifier: ICloudAccount.containerID) }

    // 내 공연은 내 iCloud(개인 저장공간), 공유받은 공연은 공유 저장공간에 있다
    private static func database(for production: Production) -> CKDatabase {
        production.isSharedWithMe ? container.sharedCloudDatabase : container.privateCloudDatabase
    }

    // 이 공연의 공유. 이미 있으면 가져오고, 없으면 새로 만든다
    static func share(for production: Production) async throws -> CKShare {
        let database = database(for: production)
        let zoneID = production.cloudZoneID
        if let existing = try await fetchShare(in: zoneID, from: database) {
            production.addMember(existing.currentUserParticipant)
            return existing
        }
        // 공유받은 공연은 주인이 이미 공유를 만들어 둔 상태 → 없으면 주인이 공유를 끊은 것
        guard !production.isSharedWithMe else { throw CKError(.unknownItem) }

        // 동기화가 아직 공연 폴더를 안 만들었을 수 있다 → 먼저 만든다 (이미 있으면 그대로)
        _ = try await database.save(CKRecordZone(zoneID: zoneID))

        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = production.title
        share.publicPermission = .readWrite   // 링크가 있는 사람 = 편집 가능
        let saved = try await database.save(share) as? CKShare ?? share
        // 공유를 처음 만든 사람(주인)도 멤버로
        production.addMember(saved.currentUserParticipant)
        return saved
    }

    // 받은 초대 수락 → 이제 나도 이 공연의 참여자. 공연 데이터는 CloudSync가 받아 온다
    static func accept(_ metadata: CKShare.Metadata) async throws {
        _ = try await container.accept(metadata)
        NotificationCenter.default.post(name: didAcceptNotification, object: nil)
    }

    // 공유받은 공연에서 "나" (이름·iCloud 계정). 공유가 없으면 nil
    static func myParticipant(in production: Production) async throws -> CKShare.Participant? {
        try await fetchShare(in: production.cloudZoneID, from: database(for: production))?.currentUserParticipant
    }

    // 폴더 공유는 이름이 정해져 있다 (CKRecordNameZoneWideShare). 없으면 nil
    private static func fetchShare(in zoneID: CKRecordZone.ID, from database: CKDatabase) async throws -> CKShare? {
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        do {
            return try await database.record(for: shareID) as? CKShare
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        }
    }
}

extension Production {
    // 공유에 들어온 사람을 이 공연의 멤버로 (iCloud 계정 ID로 "나"를 찾을 수 있게). 이미 있으면 그대로
    // 저장하면 CloudSync가 iCloud에 올려서 다른 사람에게도 보인다
    func addMember(_ participant: CKShare.Participant?) {
        guard let participant, let context = modelContext,
              let userID = participant.userIdentity.userRecordID?.recordName,
              userID != CKCurrentUserDefaultName,   // "나"라는 자리표시 이름이면 진짜 계정 ID가 아니라 건너뜀
              !(members ?? []).contains(where: { $0.iCloudUserID == userID }) else { return }

        let member = Member(name: participant.displayName, role: "")
        member.iCloudUserID = userID
        member.production = self
        context.insert(member)
        try? context.save()
    }
}

// 공유하기 창의 멤버 한 줄
struct ShareMember: Identifiable {
    let id: String
    let name: String
    let isMe: Bool
    let isOwner: Bool

    var initial: String { String(name.prefix(1)).uppercased() }
}

extension CKShare {
    // 들어와 있는 사람들 (소유자 먼저). 링크만 받고 아직 수락 안 한 사람은 빼고
    var shareMembers: [ShareMember] {
        participants
            .filter { $0.role == .owner || $0.acceptanceStatus == .accepted }
            .sorted { ($0.role == .owner ? 0 : 1) < ($1.role == .owner ? 0 : 1) }
            .map { participant in
                ShareMember(
                    id: participant.participantID,
                    name: participant.displayName,
                    isMe: participant == currentUserParticipant,
                    isOwner: participant.role == .owner
                )
            }
    }
}

extension CKShare.Participant {
    // iCloud 이름 → 없으면 이메일 → 없으면 "이름 없음"
    var displayName: String {
        if let components = userIdentity.nameComponents {
            let name = PersonNameComponentsFormatter().string(from: components)
            if !name.isEmpty { return name }
        }
        return userIdentity.lookupInfo?.emailAddress ?? "이름 없음"
    }
}
