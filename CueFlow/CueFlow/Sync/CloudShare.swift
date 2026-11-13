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
            production.fillMemberNames(from: existing)
            return existing
        }
        // 공유받은 공연은 주인이 이미 공유를 만들어 둔 상태 → 없으면 주인이 공유를 끊은 것
        guard !production.isSharedWithMe else { throw CKError(.unknownItem) }

        // 동기화가 아직 공연 폴더를 안 만들었을 수 있다 → 먼저 만든다 (이미 있으면 그대로)
        _ = try await database.save(CKRecordZone(zoneID: zoneID))

        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = production.title
        // iCloud 권한은 쓰기로 둔다 — 읽기 권한인 사람도 댓글 · 큐 확인은 올려야 해서.
        // 큐 편집은 앱 화면에서 Member.canEdit으로 막는다 (#120)
        share.publicPermission = .readWrite
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
        let share = try await fetchShare(in: production.cloudZoneID, from: database(for: production))
        if let share { production.fillMemberNames(from: share) }
        return share?.currentUserParticipant
    }

    // 공유 중인 공연이면 iCloud가 알려 주는 참여자 이름으로 빈 멤버 이름을 채운다 (공유가 없으면 아무것도 안 함)
    static func refreshMemberNames(in production: Production) async throws {
        guard let share = try await fetchShare(in: production.cloudZoneID, from: database(for: production)) else { return }
        production.fillMemberNames(from: share)
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

extension Member {
    static let unknownName = "이름 없음"

    // 진짜 이름이 아닌 자리표시 이름 (iCloud가 이름을 안 줬을 때 들어간 값)
    // "Mobile User" = 아이패드의 NSFullUserName() (#173 전에 들어간 이름)
    static func isPlaceholderName(_ name: String) -> Bool {
        name.isEmpty || name == unknownName || name == "Mobile User"
    }
}

extension Production {
    // iCloud가 공유 참여자 이름을 알려 주면, 이름이 비어 있는 멤버(이름 없음 · Mobile User)에 채운다 (#173)
    // 링크로 들어온 사람은 자기 기기에서는 자기 이름을 못 받는 경우가 많아서, 다른 사람 기기가 채워 준다
    func fillMemberNames(from share: CKShare) {
        guard let context = modelContext else { return }
        var changed = false
        for participant in share.participants {
            guard let name = participant.iCloudName,
                  let rawID = participant.userIdentity.userRecordID?.recordName else { continue }
            // "__defaultOwner__"는 "공유를 만든 사람"이다. 공유에서 "나"일 때만 내 계정 ID로 바꾼다
            let userID: String?
            if rawID == CKCurrentUserDefaultName {
                guard participant == share.currentUserParticipant else { continue }
                userID = ICloudAccount.currentUserRecordName
            } else {
                userID = rawID
            }
            guard let member = member(withUserID: userID), Member.isPlaceholderName(member.name) else { continue }
            member.name = name
            changed = true
        }
        if changed { try? context.save() }
    }

    // 공유에 들어온 사람을 이 공연의 멤버로 (iCloud 계정 ID로 "나"를 찾을 수 있게). 이미 있으면 그대로
    // 저장하면 CloudSync가 iCloud에 올려서 다른 사람에게도 보인다
    // participant는 항상 공유의 "나"(currentUserParticipant)다
    func addMember(_ participant: CKShare.Participant?) {
        guard let participant, let context = modelContext,
              let rawID = participant.userIdentity.userRecordID?.recordName else { return }
        // iCloud는 "나"를 진짜 계정 ID 대신 "__defaultOwner__"라는 자리표시 이름으로 줄 때가 있다
        // (초대받은 아이패드에서 확인, 11/13) → 내 진짜 계정 ID로 바꿔 넣는다. 그래야 역할 저장 때 "나"를 찾는다
        let userID = rawID == CKCurrentUserDefaultName ? ICloudAccount.currentUserRecordName : rawID
        guard let userID,
              !(members ?? []).contains(where: { $0.iCloudUserID == userID }) else { return }

        // 링크로 공유하면 iCloud가 이름을 안 알려 줄 때가 많다 → "이름 없음" 대신 맥 사용자 이름
        let member = Member(name: participant.iCloudName ?? CurrentEditor.name, role: "")   // 아이패드는 기기 이름이 없어서 "이름 없음" → 나중에 fillMemberNames가 채움
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
    var userID: String? = nil   // iCloud 계정 ID (Member.iCloudUserID와 비교해서 권한을 찾는다)

    var initial: String { String(name.prefix(1)).uppercased() }
}

extension CKShare {
    // 들어와 있는 사람들 (소유자 먼저). 링크만 받고 아직 수락 안 한 사람은 빼고
    func shareMembers(in production: Production) -> [ShareMember] {
        participants
            .filter { $0.role == .owner || $0.acceptanceStatus == .accepted }
            .sorted { ($0.role == .owner ? 0 : 1) < ($1.role == .owner ? 0 : 1) }
            .map { participant in
                let isMe = participant == currentUserParticipant
                let userID = participant.userIdentity.userRecordID?.recordName
                return ShareMember(
                    id: participant.participantID,
                    name: participant.iCloudName ?? appName(isMe: isMe, userID: userID, in: production),
                    isMe: isMe,
                    isOwner: participant.role == .owner,
                    userID: userID
                )
            }
    }

    // iCloud가 이름을 안 알려 주면 앱에 저장된 이름 (참여자 현황 창과 같은 이름)
    // 나 → 내 멤버 이름 · 없으면 맥 사용자 이름 / 다른 사람 → 그 사람 멤버 이름
    private func appName(isMe: Bool, userID: String?, in production: Production) -> String {
        if isMe { return CurrentEditor.name(in: production) }
        if let name = production.member(withUserID: userID)?.name, !Member.isPlaceholderName(name) { return name }
        return Member.unknownName
    }
}

extension CKShare.Participant {
    // iCloud 이름 → 없으면 이메일 → 둘 다 없으면 nil (링크 공유는 iCloud가 이름을 안 알려 줄 때가 많다)
    var iCloudName: String? {
        if let components = userIdentity.nameComponents {
            let name = PersonNameComponentsFormatter().string(from: components)
            if !name.isEmpty { return name }
        }
        return userIdentity.lookupInfo?.emailAddress
    }
}
