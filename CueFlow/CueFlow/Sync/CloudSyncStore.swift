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

    init() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: recordsURL),
           let saved = try? JSONDecoder().decode([String: Data].self, from: data) {
            records = saved
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
    }

    // 공연 폴더를 통째로 지웠을 때
    func removeRecords(in zoneID: CKRecordZone.ID) {
        records = records.filter { name, _ in
            cachedRecord(named: name)?.recordID.zoneID != zoneID
        }
        persistRecords()
    }

    // 개발용: 동기화 기록을 전부 버린다 → 다음 시작 때 "처음 동기화"가 되어 iCloud에서 전부 다시 받는다
    func removeAll() {
        records = [:]
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
