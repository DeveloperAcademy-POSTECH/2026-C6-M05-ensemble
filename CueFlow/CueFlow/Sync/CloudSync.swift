//
//  CloudSync.swift
//  CueFlow
//
//  CKSyncEngine으로 SwiftData ↔ iCloud 주고받기.
//  SwiftData에 저장될 때마다 바뀐 모델을 모아 "올릴 목록"에 넣으면, CKSyncEngine이 알아서 적당한 때 올린다.
//
//  #67 ② 올리기: 추가 · 수정 · 삭제 → iCloud
//  #67 ③ 받기: iCloud → SwiftData
//  #68 공유받은 공연: 내 공연은 내 iCloud(개인 저장공간), 공유받은 공연은 공유 저장공간 → 엔진 두 개로 따로 주고받는다
//

import AppKit
import CloudKit
import SwiftData
import os

final class CloudSync {
    // 다른 사람이 고친 걸 받아서 넣으면 보낸다 → 큐시트가 다시 그린다
    // (받은 큐·씬은 "큐.파트 = 파트"처럼 자식 쪽에서 잇는데, 그러면 파트.큐 목록을 보는 화면이 바뀐 줄 몰라서
    //  다른 일로 다시 그릴 때까지(참여자 기록 1분 등) 안 보였다)
    static let didApplyRemoteNotification = Notification.Name("CloudSync.didApplyRemote")

    private let logger = Logger(subsystem: "Happymondayy.CueFlow", category: "CloudSync")
    private let store = CloudSyncStore()

    private var privateEngine: CKSyncEngine?   // 내 공연
    private var sharedEngine: CKSyncEngine?    // 공유받은 공연
    private var context: ModelContext?
    private var saveObserver: NSObjectProtocol?
    private var acceptObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?
    private var pollTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    // 공유 중인 공연 폴더를 직접 볼 때 "어디까지 받았는지" (앱을 켤 때마다 새로 시작)
    private var directTokens: [CKRecordZone.ID: CKServerChangeToken] = [:]

    // iCloud에서 받은 걸 SwiftData에 넣는 중이면 true → 그건 다시 올리지 않는다
    private var isApplyingRemoteChanges = false

    // 받았는데 부모(예: 큐의 트리거)가 아직 안 와서 못 이은 것들. 레코드 id → 받은 레코드
    // 부모가 다음 묶음에 오면 그때 다시 잇는다
    private var unlinkedRecords: [String: CKRecord] = [:]

    // iCloud에 로그인돼 있을 때 앱이 켜지면 한 번 부른다
    func start(context: ModelContext) {
        guard privateEngine == nil, !ICloudAccount.isRunningForPreviews else { return }
        self.context = context

        let container = CKContainer(identifier: ICloudAccount.containerID)
        let savedState = store.loadState(shared: false)
        privateEngine = CKSyncEngine(CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: savedState,
            delegate: self
        ))
        sharedEngine = CKSyncEngine(CKSyncEngine.Configuration(
            database: container.sharedCloudDatabase,
            stateSerialization: store.loadState(shared: true),
            delegate: self
        ))
        observeSaves(of: context)
        observeAccepts()
        observeAppActive()
        startPolling()
        startSaving()

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
        stop()
        logger.info("이 맥 데이터 지움 → iCloud에서 다시 받기")
        start(context: context)
    }
    #endif

    // 동기화를 멈추고 "어디까지 주고받았는지" 기억을 지운다 (이 맥의 공연은 그대로)
    // 다음에 start하면 처음 동기화처럼 이 맥의 공연을 전부 다시 올린다 — 다른 계정과 섞이지 않게
    func stop() {
        for observer in [saveObserver, acceptObserver, activeObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
        saveObserver = nil
        acceptObserver = nil
        activeObserver = nil
        pollTask?.cancel()
        pollTask = nil
        saveTask?.cancel()
        saveTask = nil
        privateEngine = nil
        sharedEngine = nil
        unlinkedRecords = [:]
        directTokens = [:]
        store.removeAll()
    }

    // MARK: - 올릴 목록 만들기

    // 저장 직전에 바뀐 모델을 모은다. (저장된 뒤에는 무엇이 지워졌는지 알 수 없어서 직전에)
    private func observeSaves(of context: ModelContext) {
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.willSave, object: context, queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.collectChanges() }
        }
    }

    // 초대를 수락하면 공유받은 공연을 바로 받아 온다 (기다리면 언젠가 오지만 바로 보이게)
    private func observeAccepts() {
        acceptObserver = NotificationCenter.default.addObserver(
            forName: CloudShare.didAcceptNotification, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                do {
                    try await self?.sharedEngine?.fetchChanges()
                } catch {
                    self?.logger.error("공유받은 공연 받기 실패: \(error)")
                }
            }
        }
    }

    // 앱 창으로 돌아올 때마다 두 저장공간 다 새로 받아 온다
    // (다른 사람이 고친 건 원래 iCloud 알림(푸시)으로 오는데, 알림이 늦거나 안 와도 여기서 한 번 더 챙긴다)
    private func observeAppActive() {
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                do {
                    try await self?.privateEngine?.fetchChanges()
                    try await self?.sharedEngine?.fetchChanges()
                } catch {
                    self?.logger.error("돌아왔을 때 받기 실패: \(error)")
                }
            }
        }
    }

    // 큐시트 화면들은 직접 저장하지 않고 SwiftData 자동 저장에 맡기는데, 자동 저장은 언제 될지 모른다
    // (실제로는 참여자 현황 기록이 1분마다 저장할 때 같이 올라가서 1분씩 걸렸다)
    // → 바뀐 게 있으면 1초 안에 저장 = 저장 직전에 올릴 목록에 들어간다
    private func startSaving() {
        saveTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let context = self?.context, context.hasChanges else { continue }
                do {
                    try context.save()
                } catch {
                    self?.logger.error("자동 저장 실패: \(error)")
                }
            }
        }
    }

    // 엔진은 모았다가 몇 초 뒤에 올린다 → 고치자마자 바로 올리게
    // (지금은 willSave 안이라 저장이 끝난 다음 차례에 올라간다)
    private func sendNow(hasChanges: Bool) {
        guard hasChanges else { return }
        Task { @MainActor [weak self] in
            do {
                try await self?.privateEngine?.sendChanges()
                try await self?.sharedEngine?.sendChanges()
            } catch {
                self?.logger.error("바로 올리기 실패: \(error)")
            }
        }
    }

    // 앱을 보고 있는 동안 5초마다 새로 받아 온다
    // (iCloud 알림(푸시)이 맥에 안 오고 있어서 — 알림 기록 lastPushReceivedDate가 계속 비어 있음. 알림이 잘 오면 없애도 된다)
    private func startPolling() {
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, NSApplication.shared.isActive else { continue }
                await self.fetchSharedZonesDirectly()
                do {
                    try await self.privateEngine?.fetchChanges()
                    try await self.sharedEngine?.fetchChanges()
                } catch {
                    self.logger.error("5초마다 받기 실패: \(error)")
                }
            }
        }
    }

    private func collectChanges() {
        guard let context, privateEngine != nil, !isApplyingRemoteChanges else { return }

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

        enqueue(zoneChanges, recordChanges)
        if !recordChanges.isEmpty {
            logger.info("올릴 목록에 추가: \(recordChanges.count)개")
        }
        sendNow(hasChanges: !zoneChanges.isEmpty || !recordChanges.isEmpty)
    }

    // 폴더 주인에 따라 나눠서 올릴 목록에 넣는다 — 내 공연은 개인 저장공간, 공유받은 공연은 공유 저장공간
    // (공유받은 공연을 지우면 공유 저장공간에서 폴더를 지움 = 그 공연에서 나가기)
    private func enqueue(
        _ zoneChanges: [CKSyncEngine.PendingDatabaseChange],
        _ recordChanges: [CKSyncEngine.PendingRecordZoneChange]
    ) {
        for (engine, isMine) in [(privateEngine, true), (sharedEngine, false)] {
            guard let engine else { continue }
            let zones = zoneChanges.filter { $0.zoneID.isMine == isMine }
            let records = recordChanges.filter { $0.recordID.zoneID.isMine == isMine }
            if !zones.isEmpty {
                engine.state.add(pendingDatabaseChanges: zones)
            }
            if !records.isEmpty {
                engine.state.add(pendingRecordZoneChanges: records)
            }
        }
    }

    // 폴더 주인에 따라 어느 엔진인지
    private func engine(for zoneID: CKRecordZone.ID) -> CKSyncEngine? {
        zoneID.isMine ? privateEngine : sharedEngine
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

    // 처음 동기화할 때: 이 맥에 있는 내 공연 전부 (공유받은 공연은 공유 저장공간에서 다시 받는다)
    private func enqueueEverything() {
        guard let context else { return }
        let productions = ((try? context.fetch(FetchDescriptor<Production>())) ?? []).filter { !$0.isSharedWithMe }

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

        enqueue(productions.map { .saveZone(CKRecordZone(zoneID: $0.cloudZoneID)) }, recordIDs.map { .saveRecord($0) })
        logger.info("처음 올리기: 공연 \(productions.count)개, 레코드 \(recordIDs.count)개")
    }

    // MARK: - 올릴 때 레코드 만들기

    // CKSyncEngine이 "이거 올릴게, 내용 줘" 할 때
    fileprivate func record(for recordID: CKRecord.ID) -> CKRecord? {
        guard let id = UUID(uuidString: recordID.recordName), let item = findModel(id) else {
            // 올리기 전에 지워졌으면 목록에서 뺀다
            engine(for: recordID.zoneID)?.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
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
        let changed = context.hasChanges
        do {
            try context.save()
        } catch {
            logger.error("받은 것 저장 실패: \(error)")
        }
        if changed {
            NotificationCenter.default.post(name: CloudSync.didApplyRemoteNotification, object: nil)
        }
    }

    private func applyFetched(records: [CKRecord], deletedIDs: [CKRecord.ID]) {
        // 1) 글자 · 숫자 먼저 넣고 (없으면 새로 만들고)
        var received: [(any CloudRecordConvertible, CKRecord)] = []
        for record in records {
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
        for recordID in deletedIDs {
            store.removeRecord(recordID)
            unlinkedRecords[recordID.recordName] = nil
            if let id = UUID(uuidString: recordID.recordName), let item = findModel(id) {
                context?.delete(item)
            }
        }

        if !records.isEmpty || !deletedIDs.isEmpty {
            logger.info("받음: 저장 \(records.count)개, 삭제 \(deletedIDs.count)개")
        }
    }

    // 공유 중인 공연 폴더를 엔진을 거치지 않고 직접 확인한다
    // 엔진은 "어느 폴더가 바뀌었나" 목록(데이터베이스 변경)을 먼저 보는데, 다른 사람이 고친 건 이 목록에 1~2분 늦게 올라온다
    // (10/28 기록: 팀원은 바로 올렸는데 내 엔진은 2분 동안 "바뀐 폴더 없음"). 폴더를 직접 보면 바로 보인다
    private func fetchSharedZonesDirectly() async {
        guard let context else { return }
        let container = CKContainer(identifier: ICloudAccount.containerID)
        // 공유받은 공연 + 내 공연 중 다른 사람이 들어와 있는 것
        let productions = ((try? context.fetch(FetchDescriptor<Production>())) ?? [])
            .filter { $0.isSharedWithMe || ($0.members ?? []).count > 1 }

        for production in productions {
            let zoneID = production.cloudZoneID
            let database = zoneID.isMine ? container.privateCloudDatabase : container.sharedCloudDatabase
            let isFirst = directTokens[zoneID] == nil
            do {
                let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: directTokens[zoneID])
                directTokens[zoneID] = changes.changeToken
                // 처음엔 "여기서부터" 표시만 한다 (이미 엔진이 다 받아 둔 것)
                guard !isFirst else { continue }

                let pending = engine(for: zoneID)?.state.pendingRecordZoneChanges ?? []
                let records = changes.modificationResultsByID.values.compactMap { try? $0.get().record }.filter { record in
                    // 내가 방금 올린 것(같은 버전 꼬리표) · 아직 못 올린 내 수정이 있는 것은 건너뛴다 → 치던 글자가 되돌아가지 않게
                    store.cachedRecord(named: record.recordID.recordName)?.recordChangeTag != record.recordChangeTag
                        && !pending.contains(.saveRecord(record.recordID))
                }
                let deletedIDs = changes.deletions.map(\.recordID)
                guard !records.isEmpty || !deletedIDs.isEmpty else { continue }
                applyRemoteChanges {
                    applyFetched(records: records, deletedIDs: deletedIDs)
                }
            } catch {
                logger.error("폴더 직접 받기 실패 \(production.title): \(error)")
            }
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
        // 공연이 어느 폴더에서 왔는지 기억 → 고치면 같은 폴더(주인 쪽)로 올라간다
        if let production = item as? Production {
            let zoneID = record.recordID.zoneID
            production.cloudZoneOwnerName = zoneID.isMine ? nil : zoneID.ownerName
        }
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

    // 공유받은 공연에 "나"를 멤버로 넣는다 (iCloud 계정 ID로 연결). 이미 들어가 있으면 그대로
    // 다른 맥에서 이미 넣었으면 받은 멤버에 내 ID가 있어서 건너뛴다
    private func addMeToSharedProductions() async {
        guard let context else { return }
        guard let myID = try? await CKContainer(identifier: ICloudAccount.containerID).userRecordID().recordName else { return }

        let productions = ((try? context.fetch(FetchDescriptor<Production>())) ?? []).filter {
            $0.isSharedWithMe && !($0.members ?? []).contains { $0.iCloudUserID == myID }
        }
        for production in productions {
            do {
                production.addMember(try await CloudShare.myParticipant(in: production))
            } catch {
                logger.error("멤버 등록 실패 \(production.title): \(error)")
            }
        }
    }

    // MARK: - CKSyncEngine이 알려 주는 일

    fileprivate func handle(_ event: CKSyncEngine.Event, from engine: CKSyncEngine) {
        let isShared = engine === sharedEngine
        switch event {
        case .stateUpdate(let update):
            store.saveState(update.stateSerialization, shared: isShared)

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
            handleFailedSaves(sent.failedRecordSaves, engine: engine)
            if !sent.savedRecords.isEmpty || !sent.deletedRecordIDs.isEmpty {
                logger.info("올림: 저장 \(sent.savedRecords.count)개, 삭제 \(sent.deletedRecordIDs.count)개")
            }

        case .accountChange(let change):
            // 두 엔진이 둘 다 알려 주므로 한쪽(내 공연 엔진)에서만 처리
            guard !isShared else { break }
            // 이 맥의 공연은 지우지 않는다 — 로그아웃해도 작업하던 큐시트는 그대로 보인다
            switch change.changeType {
            case .signOut:
                logger.info("iCloud 로그아웃 → 동기화 멈춤")
                stop()
            case .switchAccounts:
                // 다른 계정이면 status가 계속 .available이라 앱이 다시 시작해 주지 않는다 → 여기서 다시 시작
                logger.info("iCloud 계정 바뀜 → 새 계정으로 처음부터 다시 올리기")
                Task { @MainActor in
                    guard let context = self.context else { return }
                    self.stop()
                    self.start(context: context)
                }
            default:
                break
            }

        case .fetchedDatabaseChanges(let fetched):
            // 다른 기기에서 공연을 지웠으면(폴더째) 이 맥에서도 지운다
            // 공유받은 공연은 주인이 공유를 끊거나 나를 내보낸 경우
            applyRemoteChanges {
                for deletion in fetched.deletions {
                    deleteProduction(in: deletion.zoneID)
                }
            }

        case .fetchedRecordZoneChanges(let fetched):
            applyRemoteChanges {
                applyFetched(records: fetched.modifications.map(\.record), deletedIDs: fetched.deletions.map(\.recordID))
            }

        case .didFetchChanges:
            // 다 받았는데도 부모를 못 찾은 게 있으면 기록만 (부모가 지워졌거나 아직 2차 대상인 경우)
            if !unlinkedRecords.isEmpty {
                logger.info("부모를 못 찾아 아직 못 이은 레코드: \(self.unlinkedRecords.count)개")
            }
            if isShared {
                Task { await addMeToSharedProductions() }
            }

        default:
            break
        }
    }

    private func handleFailedSaves(
        _ failures: [CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave], engine: CKSyncEngine
    ) {
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
                // 폴더가 없음 → 폴더부터 만들고 다시 (내 공연이 아직 이 맥에 있을 때만)
                // 공유받은 공연은 주인 폴더라 내가 만들 수 없다 → 공유가 끊긴 것. 폴더 지워짐 알림이 오면 정리된다
                guard recordID.zoneID.isMine else {
                    engine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                    continue
                }
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
        await handle(event, from: syncEngine)
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

// 올릴 목록의 한 줄이 어느 폴더 것인지 (엔진 나누기에 씀)
private extension CKSyncEngine.PendingDatabaseChange {
    var zoneID: CKRecordZone.ID {
        switch self {
        case .saveZone(let zone): zone.zoneID
        case .deleteZone(let zoneID): zoneID
        @unknown default: CKRecordZone.ID()
        }
    }
}

private extension CKSyncEngine.PendingRecordZoneChange {
    var recordID: CKRecord.ID {
        switch self {
        case .saveRecord(let recordID): recordID
        case .deleteRecord(let recordID): recordID
        @unknown default: CKRecord.ID(recordName: "")
        }
    }
}
