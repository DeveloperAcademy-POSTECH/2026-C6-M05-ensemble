//
//  CloudSyncStore.swift
//  CueFlow
//
//  동기화하면서 기억해 둘 것을 이 맥에 파일로 저장하는 곳.
//  - 동기화 진행 상태 (CKSyncEngine이 어디까지 주고받았는지)
//  - 올린 레코드의 꼬리표 (iCloud가 붙여 준 버전 정보). 다음에 고쳐서 올릴 때 "이 버전을 고친 거예요"라고 같이 보내야 한다
//
//  SwiftData 모델에 칸을 추가하지 않으려고 따로 파일로 둔다.
//

import CloudKit
import os

final class CloudSyncStore {
    private let logger = Logger(subsystem: "Happymondayy.CueFlow", category: "CloudSync")

    private let folder = URL.applicationSupportDirectory.appending(path: "CloudSync", directoryHint: .isDirectory)
    // 내 iCloud(개인 저장공간)와 공유받은 공연(공유 저장공간)은 진행 상태를 따로 둔다
    private func stateURL(shared: Bool) -> URL {
        folder.appending(path: shared ? "state-shared.json" : "state.json")
    }
    private var recordsURL: URL { folder.appending(path: "records.json") }

    // 레코드 이름(모델 id) → 꼬리표
    private var records: [String: Data] = [:]

    // 레코드 이름 → 마지막으로 iCloud와 주고받은 내용의 지문 (#217)
    // 올리기 전에 비교해서 같으면 안 올린다 → 공연을 열기만 하거나(lastOpenedAt) 댓글 · 확인을 이어도
    // 옛 값이 든 레코드를 통째로 다시 올려서 다른 사람이 고친 값을 덮어쓰지 않게
    private var fingerprints: [String: String] = [:]
    private var fingerprintsURL: URL { folder.appending(path: "fingerprints.json") }

    init() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: recordsURL),
           let saved = try? JSONDecoder().decode([String: Data].self, from: data) {
            records = saved
        }
        if let data = try? Data(contentsOf: fingerprintsURL),
           let saved = try? JSONDecoder().decode([String: String].self, from: data) {
            fingerprints = saved
        }
    }

    // MARK: 내용 지문 (#217)

    func fingerprint(named recordName: String) -> String? {
        fingerprints[recordName]
    }

    func setFingerprint(_ fingerprint: String?, named recordName: String) {
        guard fingerprints[recordName] != fingerprint else { return }
        fingerprints[recordName] = fingerprint
        persistFingerprints()
    }

    private func persistFingerprints() {
        do {
            try JSONEncoder().encode(fingerprints).write(to: fingerprintsURL)
        } catch {
            logger.error("내용 지문 저장 실패: \(error)")
        }
    }

    // MARK: 동기화 진행 상태

    // nil이면 이 맥에서 처음 동기화하는 것
    func loadState(shared: Bool) -> CKSyncEngine.State.Serialization? {
        guard let data = try? Data(contentsOf: stateURL(shared: shared)) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    func saveState(_ state: CKSyncEngine.State.Serialization, shared: Bool) {
        do {
            try JSONEncoder().encode(state).write(to: stateURL(shared: shared))
        } catch {
            logger.error("동기화 상태 저장 실패: \(error)")
        }
    }

    // MARK: 레코드 꼬리표

    // iCloud가 돌려준 레코드의 꼬리표만 저장 (내용은 SwiftData에 있음)
    func cache(_ record: CKRecord) {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        records[record.recordID.recordName] = coder.encodedData
        persistRecords()
    }

    // 꼬리표만 붙은 빈 레코드. 여기에 지금 값을 채워서 올린다
    func cachedRecord(named recordName: String) -> CKRecord? {
        guard let data = records[recordName],
              let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        defer { coder.finishDecoding() }
        return CKRecord(coder: coder)
    }

    // 한 번이라도 올라간 적 있는 모델이면 그 레코드 ID (지울 때 씀). 안 올라갔으면 nil
    func uploadedRecordID(for id: UUID) -> CKRecord.ID? {
        cachedRecord(named: id.uuidString)?.recordID
    }

    func removeRecord(_ recordID: CKRecord.ID) {
        records[recordID.recordName] = nil
        persistRecords()
        setFingerprint(nil, named: recordID.recordName)
    }

    // 공연 폴더를 통째로 지웠을 때
    func removeRecords(in zoneID: CKRecordZone.ID) {
        let removed = records.keys.filter { cachedRecord(named: $0)?.recordID.zoneID == zoneID }
        removed.forEach {
            records[$0] = nil
            fingerprints[$0] = nil
        }
        persistRecords()
        persistFingerprints()
    }

    // 개발용: 동기화 기록을 전부 버린다 → 다음 시작 때 "처음 동기화"가 되어 iCloud에서 전부 다시 받는다
    func removeAll() {
        records = [:]
        fingerprints = [:]
        try? FileManager.default.removeItem(at: fingerprintsURL)
        try? FileManager.default.removeItem(at: stateURL(shared: false))
        try? FileManager.default.removeItem(at: stateURL(shared: true))
        try? FileManager.default.removeItem(at: recordsURL)
    }

    private func persistRecords() {
        do {
            try JSONEncoder().encode(records).write(to: recordsURL)
        } catch {
            logger.error("레코드 꼬리표 저장 실패: \(error)")
        }
    }
}

extension CKRecord {
    // 내용 지문: 값만 모은 글 (버전 꼬리표 · iCloud 시간은 빼고) (#217)
    // 날짜는 초 단위까지만 — iCloud는 밀리초로 저장해서 그대로 비교하면 늘 달라 보인다
    var contentFingerprint: String {
        allKeys().sorted().map { "\($0)=\(Self.describe(self[$0]))" }.joined(separator: "\n")
    }

    private static func describe(_ value: Any?) -> String {
        switch value {
        case nil: "nil"
        case let date as Date: String(Int(date.timeIntervalSince1970.rounded()))
        case let list as [Any]: "[" + list.map { describe($0) }.joined(separator: ",") + "]"
        case let value?: String(describing: value)
        }
    }
}
