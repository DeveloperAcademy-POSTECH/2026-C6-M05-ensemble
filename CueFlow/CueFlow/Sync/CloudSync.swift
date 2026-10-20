//
//  CloudSync.swift
//  CueFlow
//
//  CKSyncEngine으로 SwiftData ↔ iCloud 주고받기.
//  SwiftData에 저장될 때마다 바뀐 모델을 모아 "올릴 목록"에 넣으면, CKSyncEngine이 알아서 적당한 때 올린다.
//
//  #67 ② 올리기: 추가 · 수정 · 삭제 → iCloud
//  #67 ③ 받기: iCloud → SwiftData
//  지금은 내 iCloud(개인 저장공간)만. 공유받은 공연(공유 저장공간)은 #68
//

import CloudKit
import SwiftData
import os

final class CloudSync {
    private let logger = Logger(subsystem: "Happymondayy.CueFlow", category: "CloudSync")
    private let store = CloudSyncStore()

    private var engine: CKSyncEngine?
    private var context: ModelContext?
    private var saveObserver: NSObjectProtocol?

    // iCloud에서 받은 걸 SwiftData에 넣는 중이면 true → 그건 다시 올리지 않는다
    private var isApplyingRemoteChanges = false

    // 받았는데 부모(예: 큐의 트리거)가 아직 안 와서 못 이은 것들. 레코드 id → 받은 레코드
    // 부모가 다음 묶음에 오면 그때 다시 잇는다
    private var unlinkedRecords: [String: CKRecord] = [:]

    // iCloud에 로그인돼 있을 때 앱이 켜지면 한 번 부른다
    func start(context: ModelContext) {
        guard engine == nil, !ICloudAccount.isRunningForPreviews else { return }
        self.context = context

        let savedState = store.loadState()
        let configuration = CKSyncEngine.Configuration(
            database: CKContainer(identifier: ICloudAccount.containerID).privateCloudDatabase,
            stateSerialization: savedState,
            delegate: self
        )
        engine = CKSyncEngine(configuration)
        observeSaves(of: context)

        // 이 맥에서 처음 동기화 → 이미 있던 공연도 전부 올린다
        if savedState == nil {
            enqueueEverything()
        }
        logger.info("동기화 시작 (처음: \(savedState == nil))")
    }

    #if DEBUG
    // 개발용 "이 맥 데이터만 지우기": iCloud는 그대로 두고 이 맥의 공연만 지운 뒤, iCloud에서 전부 다시 받는다 (③ 받기 확인용)
    func resetLocalAndRefetch() {
        guard let context else { return }
        applyRemoteChanges {   // 지운 걸 iCloud에 올리지 않게
            for production in (try? context.fetch(FetchDescriptor<Production>())) ?? [] {
                context.delete(production)
            }
        }
        if let saveObserver {
            NotificationCenter.default.removeObserver(saveObserver)
        }
        saveObserver = nil
        engine = nil
        unlinkedRecords = [:]
        store.removeAll()
        logger.info("이 맥 데이터 지움 → iCloud에서 다시 받기")
        start(context: context)
    }
    #endif

    // MARK: - 올릴 목록 만들기

    // 저장 직전에 바뀐 모델을 모은다. (저장된 뒤에는 무엇이 지워졌는지 알 수 없어서 직전에)
    private func observeSaves(of context: ModelContext) {
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.willSave, object: context, queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.collectChanges() }
        }
    }

    private func collectChanges() {
        guard let context, let engine, !isApplyingRemoteChanges else { return }

        var zoneChanges: [CKSyncEngine.PendingDatabaseChange] = []
        var recordChanges: [CKSyncEngine.PendingRecordZoneChange] = []

        for model in context.insertedModelsArray {
            // 새 공연이면 iCloud 폴더부터 만든다
            if let production = model as? Production {
                zoneChanges.append(.saveZone(CKRecordZone(zoneID: production.cloudZoneID)))
            }
            if let item = model as? any CloudRecordConvertible, let recordID = item.cloudRecordID {
                recordChanges.append(.saveRecord(recordID))
            }
        }

        for model in context.changedModelsArray {
            if let item = model as? any CloudRecordConvertible, let recordID = item.cloudRecordID {
                recordChanges.append(.saveRecord(recordID))
            }
        }

        for model in context.deletedModelsArray {
            // 공연을 지우면 폴더째 지운다 (안의 씬 · 큐도 같이 사라짐)
            if let production = model as? Production {
                zoneChanges.append(.deleteZone(production.cloudZoneID))
                continue
            }
            guard let item = model as? any CloudRecordConvertible else { continue }

            // 씬을 지우면 안의 트리거 · 큐도 같이 지워지므로(cascade) 그것들도 iCloud에서 지운다
            for id in [item.id] + cascadedIDs(of: model) {
                if let recordID = store.uploadedRecordID(for: id) {
                    recordChanges.append(.deleteRecord(recordID))
                }
            }
        }

        if !zoneChanges.isEmpty {
            engine.state.add(pendingDatabaseChanges: zoneChanges)
        }
        if !recordChanges.isEmpty {
            engine.state.add(pendingRecordZoneChanges: recordChanges)
            logger.info("올릴 목록에 추가: \(recordChanges.count)개")
        }
    }

    // 같이 지워지는 아래 모델들의 id (모델의 cascade 규칙과 맞춤)
    private func cascadedIDs(of model: any PersistentModel) -> [UUID] {
        switch model {
        case let scene as ShowScene:
            (scene.triggers ?? []).flatMap { [$0.id] + ($0.cues ?? []).map(\.id) }
        case let trigger as Trigger:
            (trigger.cues ?? []).map(\.id)
        case let part as Part:
            (part.cues ?? []).map(\.id)
        default:
            []
        }
    }

    // 처음 동기화할 때: 이 맥에 있는 공연 전부
    private func enqueueEverything() {
        guard let context, let engine else { return }
        let productions = (try? context.fetch(FetchDescriptor<Production>())) ?? []

        var recordIDs = Set<CKRecord.ID>()
        for production in productions {
            let scenes = production.scenes ?? []
            let triggers = scenes.flatMap { $0.triggers ?? [] }
            let parts = production.parts ?? []
            // 큐는 트리거 쪽과 파트 쪽 둘 다에서 모은다 (한쪽만 붙은 큐도 빠지지 않게)
            let cues = triggers.flatMap { $0.cues ?? [] } + parts.flatMap { $0.cues ?? [] }

            var items: [any CloudRecordConvertible] = [production]
            items += scenes
            items += triggers
            items += parts
            items += cues
            items += production.members ?? []
            recordIDs.formUnion(items.compactMap(\.cloudRecordID))
        }

        engine.state.add(pendingDatabaseChanges: productions.map { .saveZone(CKRecordZone(zoneID: $0.cloudZoneID)) })
        engine.state.add(pendingRecordZoneChanges: recordIDs.map { .saveRecord($0) })
        logger.info("처음 올리기: 공연 \(productions.count)개, 레코드 \(recordIDs.count)개")
    }

    // MARK: - 올릴 때 레코드 만들기

    // CKSyncEngine이 "이거 올릴게, 내용 줘" 할 때
    fileprivate func record(for recordID: CKRecord.ID) -> CKRecord? {
        guard let id = UUID(uuidString: recordID.recordName), let item = findModel(id) else {
            // 올리기 전에 지워졌으면 목록에서 뺀다
            engine?.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
            return nil
        }
        let record = store.cachedRecord(named: recordID.recordName)
            ?? CKRecord(recordType: type(of: item).recordType, recordID: recordID)
        item.fill(record)
        return record
    }

    // id로 모델 찾기 (레코드 이름만으로는 종류를 몰라서 종류마다 찾아본다)
    private func findModel(_ id: UUID) -> (any CloudRecordConvertible)? {
        guard let context else { return nil }
        if let found = try? context.fetch(FetchDescriptor<Production>(predicate: #Predicate { $0.id == id })).first { return found }
        if let found = try? context.fetch(FetchDescriptor<ShowScene>(predicate: #Predicate { $0.id == id })).first { return found }
        if let found = try? context.fetch(FetchDescriptor<Trigger>(predicate: #Predicate { $0.id == id })).first { return found }
        if let found = try? context.fetch(FetchDescriptor<Part>(predicate: #Predicate { $0.id == id })).first { return found }
        if let found = try? context.fetch(FetchDescriptor<Cue>(predicate: #Predicate { $0.id == id })).first { return found }
        if let found = try? context.fetch(FetchDescriptor<Member>(predicate: #Predicate { $0.id == id })).first { return found }
        return nil
    }

    // MARK: - 받기 (iCloud → SwiftData)

    // 받은 걸 넣는 동안에는 "바뀌었다"고 다시 올리지 않게 표시하고, 다 넣으면 저장
    private func applyRemoteChanges(_ apply: () -> Void) {
        guard let context else { return }
        isApplyingRemoteChanges = true
        defer { isApplyingRemoteChanges = false }
        apply()
        do {
            try context.save()
        } catch {
            logger.error("받은 것 저장 실패: \(error)")
        }
    }

    private func applyFetched(_ fetched: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        // 1) 글자 · 숫자 먼저 넣고 (없으면 새로 만들고)
        var received: [(any CloudRecordConvertible, CKRecord)] = []
        for modification in fetched.modifications {
            let record = modification.record
            store.cache(record)
            if let item = upsert(record) {
                received.append((item, record))
            }
        }

        // 2) 관계 잇기. 같은 묶음 안에 부모가 있을 수 있어서 다 넣은 다음에
        for (item, record) in received {
            if link(item, from: record) {
                unlinkedRecords[record.recordID.recordName] = nil
            } else {
                unlinkedRecords[record.recordID.recordName] = record
            }
        }

        // 3) 전에 못 이었던 것 중 이번에 부모가 온 것 다시 잇기
        for (name, record) in unlinkedRecords {
            guard let id = UUID(uuidString: name), let item = findModel(id) else {
                unlinkedRecords[name] = nil
                continue
            }
            if link(item, from: record) {
                unlinkedRecords[name] = nil
            }
        }

        // 4) 지운 것
        for deletion in fetched.deletions {
            store.removeRecord(deletion.recordID)
            unlinkedRecords[deletion.recordID.recordName] = nil
            if let id = UUID(uuidString: deletion.recordID.recordName), let item = findModel(id) {
                context?.delete(item)
            }
        }

        if !fetched.modifications.isEmpty || !fetched.deletions.isEmpty {
            logger.info("받음: 저장 \(fetched.modifications.count)개, 삭제 \(fetched.deletions.count)개")
        }
    }

    // 이미 있으면 그 모델에, 없으면 새로 만들어서 값 넣기
    private func upsert(_ record: CKRecord) -> (any CloudRecordConvertible)? {
        guard let context, let id = UUID(uuidString: record.recordID.recordName) else { return nil }

        var item: any CloudRecordConvertible
        if let existing = findModel(id) {
            item = existing
        } else {
            switch record.recordType {
            case Production.recordType: item = Production(title: "", genre: "", firstShowDate: .now)
            case ShowScene.recordType: item = ShowScene(title: "", kind: .scene, order: 0)
            case Trigger.recordType: item = Trigger(text: "", order: 0)
            case Part.recordType: item = Part(name: "", order: 0, colorIndex: 0)
            case Cue.recordType: item = Cue(title: "", position: .stage, order: 0)
            case Member.recordType: item = Member(name: "", role: "")
            default: return nil   // 모르는 종류 (2차 대상 등)
            }
            item.id = id
            context.insert(item)
        }
        item.applyFields(from: record)
        return item
    }

    // 부모 id로 관계 잇기. 부모를 아직 못 찾았으면 false
    private func link(_ item: any CloudRecordConvertible, from record: CKRecord) -> Bool {
        // 부모 id가 적혀 있으면 찾아서 반환, 적혀 있지 않으면 nil (부모 없음이 맞는 경우)
        func parent<T>(_ key: String, as type: T.Type, found: inout Bool) -> T? {
            guard let id = record.uuid(key) else { return nil }
            let model = findModel(id) as? T
            if model == nil { found = false }
            return model
        }

        var found = true
        switch item {
        case let scene as ShowScene:
            scene.production = parent(CloudKey.productionID, as: Production.self, found: &found)
        case let trigger as Trigger:
            trigger.scene = parent(CloudKey.sceneID, as: ShowScene.self, found: &found)
        case let part as Part:
            part.production = parent(CloudKey.productionID, as: Production.self, found: &found)
        case let cue as Cue:
            cue.trigger = parent(CloudKey.triggerID, as: Trigger.self, found: &found)
            cue.part = parent(CloudKey.partID, as: Part.self, found: &found)
        case let member as Member:
            member.production = parent(CloudKey.productionID, as: Production.self, found: &found)
            let partIDs = record.uuids(CloudKey.partIDs)
            let parts = partIDs.compactMap { findModel($0) as? Part }
            member.parts = parts
            if parts.count < partIDs.count { found = false }
        default:
            break   // 공연은 부모가 없다
        }
        return found
    }

    // 공연 폴더가 지워졌을 때 그 공연 지우기 (폴더 이름 = "Production-공연id")
    private func deleteProduction(in zoneID: CKRecordZone.ID) {
        store.removeRecords(in: zoneID)
        let idText = zoneID.zoneName.replacingOccurrences(of: "Production-", with: "")
        guard let id = UUID(uuidString: idText), let production = findModel(id) as? Production else { return }
        context?.delete(production)
        logger.info("받음: 공연 지워짐 \(production.title)")
    }

    // MARK: - CKSyncEngine이 알려 주는 일

    fileprivate func handle(_ event: CKSyncEngine.Event) {
        switch event {
        case .stateUpdate(let update):
            store.saveState(update.stateSerialization)

        case .sentDatabaseChanges(let sent):
            for zoneID in sent.deletedZoneIDs {
                store.removeRecords(in: zoneID)
            }
            for failure in sent.failedZoneSaves {
                logger.error("폴더 만들기 실패 \(failure.zone.zoneID.zoneName): \(failure.error)")
            }

        case .sentRecordZoneChanges(let sent):
            for record in sent.savedRecords {
                store.cache(record)
            }
            for recordID in sent.deletedRecordIDs {
                store.removeRecord(recordID)
            }
            handleFailedSaves(sent.failedRecordSaves)
            if !sent.savedRecords.isEmpty || !sent.deletedRecordIDs.isEmpty {
                logger.info("올림: 저장 \(sent.savedRecords.count)개, 삭제 \(sent.deletedRecordIDs.count)개")
            }

        case .accountChange(let change):
            // TODO: 로그아웃 · 다른 계정으로 바꿨을 때 처리
            logger.info("iCloud 계정 바뀜: \(String(describing: change.changeType))")

        case .fetchedDatabaseChanges(let fetched):
            // 다른 기기에서 공연을 지웠으면(폴더째) 이 맥에서도 지운다
            applyRemoteChanges {
                for deletion in fetched.deletions {
                    deleteProduction(in: deletion.zoneID)
                }
            }

        case .fetchedRecordZoneChanges(let fetched):
            applyRemoteChanges {
                applyFetched(fetched)
            }

        case .didFetchChanges:
            // 다 받았는데도 부모를 못 찾은 게 있으면 기록만 (부모가 지워졌거나 아직 2차 대상인 경우)
            if !unlinkedRecords.isEmpty {
                logger.info("부모를 못 찾아 아직 못 이은 레코드: \(self.unlinkedRecords.count)개")
            }

        default:
            break
        }
    }

    private func handleFailedSaves(_ failures: [CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave]) {
        guard let engine else { return }
        for failure in failures {
            let recordID = failure.record.recordID
            switch failure.error.code {
            case .serverRecordChanged:
                // 그새 다른 기기가 고쳤음 → iCloud 버전 꼬리표를 받아서 내 값으로 다시 올린다 (나중에 올린 게 이김)
                if let serverRecord = failure.error.serverRecord {
                    store.cache(serverRecord)
                }
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])

            case .zoneNotFound:
                // 폴더가 없음 → 폴더부터 만들고 다시 (공연이 아직 이 맥에 있을 때만)
                guard let id = UUID(uuidString: recordID.recordName), findModel(id) != nil else { continue }
                engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: recordID.zoneID))])
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])

            case .unknownItem:
                // iCloud에서 지워진 레코드 → 꼬리표 버리고 새로 올린다
                store.removeRecord(recordID)
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])

            default:
                logger.error("올리기 실패 \(recordID.recordName): \(failure.error)")
            }
        }
    }
}

// CKSyncEngine은 메인 스레드가 아닌 곳에서 부르므로, 받자마자 메인으로 넘긴다
extension CloudSync: CKSyncEngineDelegate {
    nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await handle(event)
    }

    nonisolated func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { recordID in
            await self.record(for: recordID)
        }
    }
}
