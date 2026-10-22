//
//  CloudShare.swift
//  CueFlow
//
//  공연 공유(CKShare) — 공연 폴더(레코드 존)를 통째로 공유하고 초대 링크를 만든다 (#68).
//  팀 결정: 공연에 들어온 사람 누구나 초대할 수 있고, 초대받은 사람도 편집할 수 있다
//  → 링크가 있는 사람은 누구나 "편집 가능"으로 참여.
//  우리 앱엔 서버가 없어서 초대 메일은 iCloud가 아니라 이 맥의 메일 앱으로 보낸다 (SharePopover).
//

import CloudKit

enum CloudShare {
    private static var database: CKDatabase {
        CKContainer(identifier: ICloudAccount.containerID).privateCloudDatabase
    }

    // 이 공연의 공유. 이미 있으면 가져오고, 없으면 새로 만든다
    // TODO: 공유받은 공연(공유 저장공간)에서 초대할 때는 sharedCloudDatabase에서 찾기 (#68 3단계)
    static func share(for production: Production) async throws -> CKShare {
        let zoneID = production.cloudZoneID
        if let existing = try await fetchShare(in: zoneID) {
            return existing
        }

        // 동기화가 아직 공연 폴더를 안 만들었을 수 있다 → 먼저 만든다 (이미 있으면 그대로)
        _ = try await database.save(CKRecordZone(zoneID: zoneID))

        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = production.title
        share.publicPermission = .readWrite   // 링크가 있는 사람 = 편집 가능
        let saved = try await database.save(share)
        return saved as? CKShare ?? share
    }

    // 받은 초대 수락 → 이제 나도 이 공연의 참여자 (공연 데이터 받아 오기는 #68 3단계)
    static func accept(_ metadata: CKShare.Metadata) async throws {
        _ = try await CKContainer(identifier: ICloudAccount.containerID).accept(metadata)
    }

    // 폴더 공유는 이름이 정해져 있다 (CKRecordNameZoneWideShare). 없으면 nil
    private static func fetchShare(in zoneID: CKRecordZone.ID) async throws -> CKShare? {
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        do {
            return try await database.record(for: shareID) as? CKShare
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        }
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
