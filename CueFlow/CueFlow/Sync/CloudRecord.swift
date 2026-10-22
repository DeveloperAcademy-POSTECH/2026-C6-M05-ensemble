//
//  CloudRecord.swift
//  CueFlow
//
//  SwiftData 모델 ↔ CloudKit 레코드(iCloud에 올라가는 한 장의 카드) 바꾸기.
//  공연 하나 = iCloud 폴더(레코드 존) 하나. 공연을 공유하면 그 폴더 통째로 공유된다 (#68).
//  레코드 이름 = 모델의 id(UUID) → 기기가 달라도 같은 큐는 같은 이름.
//
//  1차: 공연 · 씬 · 트리거 · 파트 · 큐 · 멤버. (댓글 · 확인 · 대본 · 무대 배치는 2차)
//  관계(어느 씬의 트리거인지 등)는 부모의 id를 적어 두고, 받을 때(#67 ③단계) id로 찾아서 다시 잇는다.
//

import CloudKit
import SwiftData

// iCloud에 올릴 수 있는 모델
protocol CloudRecordConvertible: PersistentModel {
    static var recordType: String { get }
    var id: UUID { get set }

    // 이 모델이 들어갈 공연 (= iCloud 폴더). 아직 공연에 안 붙었으면 nil → 올리지 않는다
    var cloudProduction: Production? { get }

    // 내 값 → 레코드 (관계는 부모 id로)
    func fill(_ record: CKRecord)

    // 레코드 → 내 값 (관계 빼고 글자·숫자만. 관계는 받는 단계에서 잇는다)
    func applyFields(from record: CKRecord)
}

extension CloudRecordConvertible {
    var cloudRecordID: CKRecord.ID? {
        guard let production = cloudProduction else { return nil }
        return CKRecord.ID(recordName: id.uuidString, zoneID: production.cloudZoneID)
    }
}

// MARK: - 공연 = iCloud 폴더

extension Production {
    // 공연마다 폴더 하나. 이름은 공연 id로 만들어서 기기가 달라도 같다
    var cloudZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "Production-\(id.uuidString)")
    }
}

// MARK: - 레코드 칸 이름

// 레코드 안의 칸 이름. 한 번 정하면 바꾸지 말 것 (이미 올라간 데이터와 안 맞게 됨)
enum CloudKey {
    static let title = "title"
    static let genre = "genre"
    static let firstShowDate = "firstShowDate"
    static let createdAt = "createdAt"
    static let updatedAt = "updatedAt"
    static let castNames = "castNames"
    static let propNames = "propNames"
    static let kind = "kind"
    static let order = "order"
    static let hasOwnPlacements = "hasOwnPlacements"
    static let text = "text"
    static let name = "name"
    static let colorIndex = "colorIndex"
    static let position = "position"
    static let stageCell = "stageCell"
    static let role = "role"
    static let iCloudUserID = "iCloudUserID"

    // 부모 id (관계)
    static let productionID = "productionID"
    static let sceneID = "sceneID"
    static let triggerID = "triggerID"
    static let partID = "partID"
    static let partIDs = "partIDs"     // 멤버가 맡은 파트들 (여러 개)
}

extension Array where Element == String {
    // iCloud는 처음 보는 칸에 빈 목록을 넣으면 "무슨 목록인지 모른다"며 거절한다 → 비었으면 칸을 비운다(nil)
    var cloudList: [String]? { isEmpty ? nil : self }
}

extension CKRecord {
    // 부모 id 읽기 (받는 단계에서 관계 잇기에 씀)
    func uuid(_ key: String) -> UUID? {
        (self[key] as? String).flatMap(UUID.init(uuidString:))
    }

    func uuids(_ key: String) -> [UUID] {
        ((self[key] as? [String]) ?? []).compactMap(UUID.init(uuidString:))
    }
}

// MARK: - 모델별 바꾸기

extension Production: CloudRecordConvertible {
    static let recordType = "Production"

    var cloudProduction: Production? { self }

    // isFavorite · lastOpenedAt은 "나한테만" 의미 있는 값이라 올리지 않는다
    // TODO: #63(PR #65) 머지 후 lastShowDate · venue · seatCount · organizer · runningTime 추가
    func fill(_ record: CKRecord) {
        record[CloudKey.title] = title
        record[CloudKey.genre] = genre
        record[CloudKey.firstShowDate] = firstShowDate
        record[CloudKey.createdAt] = createdAt
        record[CloudKey.updatedAt] = updatedAt
        record[CloudKey.castNames] = castNames.cloudList
        record[CloudKey.propNames] = propNames.cloudList
    }

    func applyFields(from record: CKRecord) {
        title = record[CloudKey.title] as? String ?? ""
        genre = record[CloudKey.genre] as? String ?? ""
        firstShowDate = record[CloudKey.firstShowDate] as? Date ?? Date()
        createdAt = record[CloudKey.createdAt] as? Date ?? Date()
        updatedAt = record[CloudKey.updatedAt] as? Date ?? Date()
        castNames = record[CloudKey.castNames] as? [String] ?? []
        propNames = record[CloudKey.propNames] as? [String] ?? []
    }
}

extension ShowScene: CloudRecordConvertible {
    static let recordType = "ShowScene"

    var cloudProduction: Production? { production }

    func fill(_ record: CKRecord) {
        record[CloudKey.title] = title
        record[CloudKey.kind] = kind.rawValue
        record[CloudKey.order] = order
        record[CloudKey.hasOwnPlacements] = hasOwnPlacements
        record[CloudKey.productionID] = production?.id.uuidString
    }

    func applyFields(from record: CKRecord) {
        title = record[CloudKey.title] as? String ?? ""
        kind = (record[CloudKey.kind] as? String).flatMap(SceneKind.init(rawValue:)) ?? .scene
        order = record[CloudKey.order] as? Int ?? 0
        hasOwnPlacements = record[CloudKey.hasOwnPlacements] as? Bool ?? false
    }
}

extension Trigger: CloudRecordConvertible {
    static let recordType = "Trigger"

    var cloudProduction: Production? { scene?.production }

    func fill(_ record: CKRecord) {
        record[CloudKey.text] = text
        record[CloudKey.order] = order
        record[CloudKey.sceneID] = scene?.id.uuidString
    }

    func applyFields(from record: CKRecord) {
        text = record[CloudKey.text] as? String ?? ""
        order = record[CloudKey.order] as? Int ?? 0
    }
}

extension Part: CloudRecordConvertible {
    static let recordType = "Part"

    var cloudProduction: Production? { production }

    func fill(_ record: CKRecord) {
        record[CloudKey.name] = name
        record[CloudKey.order] = order
        record[CloudKey.colorIndex] = colorIndex
        record[CloudKey.productionID] = production?.id.uuidString
    }

    func applyFields(from record: CKRecord) {
        name = record[CloudKey.name] as? String ?? ""
        order = record[CloudKey.order] as? Int ?? 0
        colorIndex = record[CloudKey.colorIndex] as? Int ?? 0
    }
}

extension Cue: CloudRecordConvertible {
    static let recordType = "Cue"

    // 큐는 트리거(씬) 쪽으로 공연을 찾고, 없으면 파트 쪽으로
    var cloudProduction: Production? { trigger?.scene?.production ?? part?.production }

    func fill(_ record: CKRecord) {
        record[CloudKey.title] = title
        record[CloudKey.position] = position.rawValue
        record[CloudKey.order] = order
        record[CloudKey.createdAt] = createdAt
        record[CloudKey.stageCell] = stageCell
        record[CloudKey.triggerID] = trigger?.id.uuidString
        record[CloudKey.partID] = part?.id.uuidString
    }

    func applyFields(from record: CKRecord) {
        title = record[CloudKey.title] as? String ?? ""
        position = (record[CloudKey.position] as? String).flatMap(CuePosition.init(rawValue:)) ?? .stage
        order = record[CloudKey.order] as? Int ?? 0
        createdAt = record[CloudKey.createdAt] as? Date ?? Date()
        stageCell = record[CloudKey.stageCell] as? Int
    }
}

extension Member: CloudRecordConvertible {
    static let recordType = "Member"

    var cloudProduction: Production? { production }

    func fill(_ record: CKRecord) {
        record[CloudKey.name] = name
        record[CloudKey.role] = role
        record[CloudKey.iCloudUserID] = iCloudUserID
        record[CloudKey.productionID] = production?.id.uuidString
        record[CloudKey.partIDs] = (parts ?? []).map(\.id.uuidString).cloudList
    }

    func applyFields(from record: CKRecord) {
        name = record[CloudKey.name] as? String ?? ""
        role = record[CloudKey.role] as? String ?? ""
        iCloudUserID = record[CloudKey.iCloudUserID] as? String
    }
}
