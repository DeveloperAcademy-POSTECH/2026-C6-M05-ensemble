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
//  #69 리허설 동기화 모드: 공연 폴더에 "리허설 위치" 레코드도 같이 주고받는다 (SwiftData 모델 아님 → RehearsalSync)
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

    // 이 맥에 처음 들어온 공지가 있으면 보낸다 (object = 공지 id들) → 알림 카드 (#82)
    static let didReceiveNoticesNotification = Notification.Name("CloudSync.didReceiveNotices")

    private let logger = Logger(subsystem: "Happymondayy.CueFlow", category: "CloudSync")
    private let store = CloudSyncStore()

    private var privateEngine: CKSyncEngine?   // 내 공연
    private var sharedEngine: CKSyncEngine?    // 공유받은 공연
    private var context: ModelContext?
    private var saveObserver: NSObjectProtocol?
    private var acceptObserver: NSObjectProtocol?
    private var rehearsalObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?
    private var pollTask: Task<Void, Never>?
    private var rehearsalPollTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    // 리허설 위치를 올리는 중인 공연 / 올리는 중에 또 넘겨서 끝나면 한 번 더 올릴 공연
    private var sendingRehearsal: Set<UUID> = []
    private var resendRehearsal: Set<UUID> = []
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
        observeRehearsal()
        observeAppActive()
        startPolling()
        startRehearsalPolling()
        startSaving()

        // 이 맥에서 처음 동기화 → 이미 있던 공연도 전부 올린다
        if savedState == nil {
            enqueueEverything()
        }
        enqueueScriptsAndPlacementsOnce()
        enqueueHistoriesOnce()
        enqueueCommentsAndChecksOnce()
        enqueueNoticesOnce()
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
        for observer in [saveObserver, acceptObserver, rehearsalObserver, activeObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
        saveObserver = nil
        acceptObserver = nil
        rehearsalObserver = nil
        activeObserver = nil
        pollTask?.cancel()
        pollTask = nil
        rehearsalPollTask?.cancel()
        rehearsalPollTask = nil
        saveTask?.cancel()
        saveTask = nil
        privateEngine = nil
        sharedEngine = nil
        unlinkedRecords = [:]
        directTokens = [:]
        store.removeAll()
    }

    // 리허설 화면이 열려 있으면 그 공연의 "리허설 위치" 한 장만 0.5초마다 직접 확인한다
    // (2초마다 공연 폴더 전체를 보는 것만으로는 따라가기가 최대 2초 늦었다. 한 장만 보는 건 가벼워서 자주 봐도 된다)
    private func startRehearsalPolling() {
        rehearsalPollTask = Task { @MainActor [weak self] in
            var lastTag: String?
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.5))
                guard let self, let productionID = RehearsalSync.shared.watchingProductionID,
                      let production = self.findModel(productionID) as? Production else { continue }
                let zoneID = production.cloudZoneID
                let container = CKContainer(identifier: ICloudAccount.containerID)
                let database = zoneID.isMine ? container.privateCloudDatabase : container.sharedCloudDatabase
                let recordID = CKRecord.ID(recordName: RehearsalSync.recordName(for: productionID), zoneID: zoneID)
                do {
                    let record = try await database.record(for: recordID)
                    guard record.recordChangeTag != lastTag else { continue }
                    lastTag = record.recordChangeTag
                    RehearsalSync.shared.receive(record)
                    // 따라가기가 얼마나 늦는지 (다른 맥과 시계가 조금 다를 수 있음. 가짜 진행자로 맥 한 대에서 재면 정확)
                    if let sentAt = record["updatedAt"] as? Date {
                        self.logger.info("리허설 위치 받음: 올린 지 \(Date.now.timeIntervalSince(sentAt), format: .fixed(precision: 2))초")
                    }
                } catch let error as CKError where error.code == .unknownItem {
                    // 아직 아무도 진행한 적 없는 공연
                } catch {
                    self.logger.error("리허설 위치 확인 실패: \(error)")
                }
            }
        }
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

    // 리허설 진행 위치가 바뀌면 기다리지 않고 바로 올린다 (따라가는 사람이 늦게 넘어가지 않게)
    private func observeRehearsal() {
        rehearsalObserver = NotificationCenter.default.addObserver(
            forName: RehearsalSync.didChangeNotification, object: nil, queue: nil
        ) { [weak self] notification in
            guard let productionID = notification.object as? UUID else { return }
            MainActor.assumeIsolated { self?.sendRehearsalPosition(of: productionID) }
        }
    }

    // 엔진을 거치지 않고 바로 덮어쓴다 (10/29 맥 2대 테스트: 스페이스로 빨리 넘기면 따라가는 쪽이 한참 늦었음)
    // - 엔진으로 올리면 앞의 것이 올라가는 중에 같은 레코드를 또 올려서 "그새 바뀜"으로 거절 → 다시 올리느라 더 늦어졌다
    // - 위치는 마지막 것만 의미 있으니 버전 확인 없이 덮어쓰고(.allKeys), 올리는 중에 또 넘기면 끝난 뒤 마지막 위치로 한 번만 더
    private func sendRehearsalPosition(of productionID: UUID) {
        guard !sendingRehearsal.contains(productionID) else {
            resendRehearsal.insert(productionID)
            return
        }
        guard let production = findModel(productionID) as? Production else { return }
        let zoneID = production.cloudZoneID
        let container = CKContainer(identifier: ICloudAccount.containerID)
        let database = zoneID.isMine ? container.privateCloudDatabase : container.sharedCloudDatabase
        let recordID = CKRecord.ID(recordName: RehearsalSync.recordName(for: productionID), zoneID: zoneID)

        sendingRehearsal.insert(productionID)
        Task { @MainActor [weak self] in
            repeat {
                self?.resendRehearsal.remove(productionID)
                let record = CKRecord(recordType: RehearsalSync.recordType, recordID: recordID)
                RehearsalSync.shared.fill(record, productionID: productionID)
                do {
                    let (saved, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
                    if case .failure(let error) = saved[recordID] {
                        self?.logger.error("리허설 위치 올리기 실패: \(error)")
                    }
                } catch {
                    self?.logger.error("리허설 위치 올리기 실패: \(error)")
                }
            } while self?.resendRehearsal.contains(productionID) == true
            self?.sendingRehearsal.remove(productionID)
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

    // 앱이 켜져 있는 동안 지금 보고 있는 공연 폴더는 2초마다, 전체는 10초마다 직접 받아 온다
    // (iCloud 알림(푸시)이 맥에 안 오고 있어서 — 알림 기록 lastPushReceivedDate가 계속 비어 있음. 알림이 잘 오면 없애도 된다)
    private func startPolling() {
        pollTask = Task { @MainActor [weak self] in
            var round = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                // 다른 앱을 누르고 있어도 Cuedit 창은 옆에 떠 있을 수 있어서, 켜져 있으면 항상 본다
                guard let self else { continue }
                round += 1
                await self.fetchSharedZonesDirectly(onlyRecent: round % 5 != 0)
                guard round % 5 == 0 else { continue }
                do {
                    try await self.privateEngine?.fetchChanges()
                    try await self.sharedEngine?.fetchChanges()
                } catch {
                    self.logger.error("10초마다 받기 실패: \(error)")
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
            (scene.triggers ?? []).flatMap { [$0.id] + Self.cueTreeIDs($0.cues) }
                + (scene.scriptLines ?? []).map(\.id)
                + (scene.placements ?? []).map(\.id)
        case let trigger as Trigger:
            Self.cueTreeIDs(trigger.cues)
        case let part as Part:
            Self.cueTreeIDs(part.cues)
        case let cue as Cue:
            Self.cueChildIDs(cue)
        case let comment as Comment:
            Self.replyIDs(comment)
        case let member as Member:
            // 멤버가 나가면 확인 · 공지 읽음은 지운다 (댓글 · 보낸 공지는 남김)
            (member.checks ?? []).map(\.id) + (member.noticeReads ?? []).map(\.id)
        case let notice as Notice:
            (notice.reads ?? []).map(\.id)
        default:
            []
        }
    }

    // 큐들 + 그 큐들에 딸린 것 id — 큐를 지우면 기록 · 댓글 · 확인도 같이 지워진다 (Cue cascade)
    private static func cueTreeIDs(_ cues: [Cue]?) -> [UUID] {
        (cues ?? []).flatMap { [$0.id] + cueChildIDs($0) }
    }

    private static func cueChildIDs(_ cue: Cue) -> [UUID] {
        (cue.histories ?? []).map(\.id)
            + (cue.comments ?? []).flatMap { [$0.id] + replyIDs($0) }
            + (cue.checks ?? []).map(\.id)
    }

    // 댓글을 지우면 답글도 같이 지워진다 (답글의 답글까지)
    private static func replyIDs(_ comment: Comment) -> [UUID] {
        (comment.replies ?? []).flatMap { [$0.id] + replyIDs($0) }
    }

    // #86 전에는 대본 · 무대 배치를 안 올렸다 → 이 맥에 이미 있던 것을 한 번만 올린다
    // 공유받은 공연에 내가 넣은 대본도 올린다 (친구도 따로 넣었으면 두 벌이 되는데, 한쪽에서 대본을 다시 넣으면 정리된다)
    private func enqueueScriptsAndPlacementsOnce() {
        let key = "didUploadScriptsAndPlacements"
        guard let context, !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        var items: [any CloudRecordConvertible] = []
        for production in (try? context.fetch(FetchDescriptor<Production>())) ?? [] {
            let scenes = production.scenes ?? []
            items += scenes.flatMap { $0.scriptLines ?? [] }
            items += scenes.flatMap { $0.placements ?? [] }
            items += production.initialPlacements ?? []
        }
        let recordIDs = items.compactMap(\.cloudRecordID)
        enqueue([], recordIDs.map { .saveRecord($0) })
        logger.info("대본 · 무대 배치 처음 올리기: \(recordIDs.count)개")
    }

    // 공지 · 읽음(#33)도 #82 전에는 안 올렸다 → 이 맥에 이미 있던 것을 한 번만 올린다
    private func enqueueNoticesOnce() {
        let key = "didUploadNotices"
        guard let context, !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        var items: [any CloudRecordConvertible] = (try? context.fetch(FetchDescriptor<Notice>())) ?? []
        items += (try? context.fetch(FetchDescriptor<NoticeRead>())) ?? []
        let recordIDs = items.compactMap(\.cloudRecordID)
        enqueue([], recordIDs.map { .saveRecord($0) })
        logger.info("공지 · 읽음 처음 올리기: \(recordIDs.count)개")
    }

    // 댓글 · 확인(#96)도 #98 전에는 안 올렸다 → 이 맥에 이미 있던 것을 한 번만 올린다
    private func enqueueCommentsAndChecksOnce() {
        let key = "didUploadCommentsAndChecks"
        guard let context, !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        var items: [any CloudRecordConvertible] = (try? context.fetch(FetchDescriptor<Comment>())) ?? []
        items += (try? context.fetch(FetchDescriptor<CueCheck>())) ?? []
        let recordIDs = items.compactMap(\.cloudRecordID)
        enqueue([], recordIDs.map { .saveRecord($0) })
        logger.info("댓글 · 확인 처음 올리기: \(recordIDs.count)개")
    }

    // 큐 기록(History, #83)도 #86 전에는 안 올렸다 → 이 맥에 이미 있던 기록을 한 번만 올린다
    private func enqueueHistoriesOnce() {
        let key = "didUploadCueHistories"
        guard let context, !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let histories = (try? context.fetch(FetchDescriptor<CueHistory>())) ?? []
        let recordIDs = histories.compactMap(\.cloudRecordID)
        enqueue([], recordIDs.map { .saveRecord($0) })
        logger.info("큐 기록 처음 올리기: \(recordIDs.count)개")
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
            items += scenes.flatMap { $0.scriptLines ?? [] }
            items += scenes.flatMap { $0.placements ?? [] }
            items += production.initialPlacements ?? []
            items += cues.flatMap { $0.histories ?? [] }
            items += cues.flatMap { $0.comments ?? [] }   // 답글도 큐에 붙어 있어서 여기 같이 들어온다
            items += cues.flatMap { $0.checks ?? [] }
            items += production.notices ?? []
            items += (production.notices ?? []).flatMap { $0.reads ?? [] }
            recordIDs.formUnion(items.compactMap(\.cloudRecordID))
        }

        enqueue(productions.map { .saveZone(CKRecordZone(zoneID: $0.cloudZoneID)) }, recordIDs.map { .saveRecord($0) })
        logger.info("처음 올리기: 공연 \(productions.count)개, 레코드 \(recordIDs.count)개")
    }

    // MARK: - 올릴 때 레코드 만들기

    // CKSyncEngine이 "이거 올릴게, 내용 줘" 할 때
    fileprivate func record(for recordID: CKRecord.ID) -> CKRecord? {
        // 리허설 위치는 모델이 아니라 RehearsalSync가 들고 있는 값으로 채운다
        if let productionID = RehearsalSync.productionID(fromRecordName: recordID.recordName) {
            let record = store.cachedRecord(named: recordID.recordName)
                ?? CKRecord(recordType: RehearsalSync.recordType, recordID: recordID)
            RehearsalSync.shared.fill(record, productionID: productionID)
            return record
        }
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
        if let found = try? context.fetch(FetchDescriptor<ScriptLine>(predicate: #Predicate { $0.id == id })).first { return found }
        if let found = try? context.fetch(FetchDescriptor<StagePlacement>(predicate: #Predicate { $0.id == id })).first { return found }
        if let found = try? context.fetch(FetchDescriptor<CueHistory>(predicate: #Predicate { $0.id == id })).first { return found }
        if let found = try? context.fetch(FetchDescriptor<Comment>(predicate: #Predicate { $0.id == id })).first { return found }
        if let found = try? context.fetch(FetchDescriptor<CueCheck>(predicate: #Predicate { $0.id == id })).first { return found }
        if let found = try? context.fetch(FetchDescriptor<Notice>(predicate: #Predicate { $0.id == id })).first { return found }
        if let found = try? context.fetch(FetchDescriptor<NoticeRead>(predicate: #Predicate { $0.id == id })).first { return found }
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
        var newNoticeIDs: [UUID] = []
        for record in records {
            store.cache(record)
            if record.recordType == RehearsalSync.recordType {
                RehearsalSync.shared.receive(record)
                continue
            }
            if record.recordType == Notice.recordType,
               let id = UUID(uuidString: record.recordID.recordName), findModel(id) == nil {
                newNoticeIDs.append(id)
            }
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

        // 저장이 끝난 다음에 알린다 (받는 쪽이 공지 · 보낸 사람 · 읽음을 다 이은 상태로 보게)
        if !newNoticeIDs.isEmpty {
            Task { @MainActor in
                NotificationCenter.default.post(name: CloudSync.didReceiveNoticesNotification, object: newNoticeIDs)
            }
        }

        if !records.isEmpty || !deletedIDs.isEmpty {
            let kinds = records.map(\.recordType).joined(separator: ", ")
            logger.info("받음: 저장 \(records.count)개 [\(kinds)], 삭제 \(deletedIDs.count)개")
        }
    }

    // 공유 중인 공연 폴더를 엔진을 거치지 않고 직접 확인한다
    // 엔진은 "어느 폴더가 바뀌었나" 목록(데이터베이스 변경)을 먼저 보는데, 다른 사람이 고친 건 이 목록에 1~2분 늦게 올라온다
    // (10/28 기록: 팀원은 바로 올렸는데 내 엔진은 2분 동안 "바뀐 폴더 없음"). 폴더를 직접 보면 바로 보인다
    // onlyRecent: true면 마지막으로 연 공연(지금 보고 있는 공연)만, false면 전부
    private func fetchSharedZonesDirectly(onlyRecent: Bool) async {
        guard let context else { return }
        let container = CKContainer(identifier: ICloudAccount.containerID)
        // 멤버 수로 "공유 중"을 가리면 안 된다 — 친구의 멤버 정보가 아직 안 왔으면 내 공연이 빠져서 친구 수정이 늦게 왔다 (10/28)
        let all = ((try? context.fetch(FetchDescriptor<Production>())) ?? []).sorted { $0.lastOpenedAt > $1.lastOpenedAt }
        let productions = onlyRecent ? Array(all.prefix(1)) : all

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
            case ScriptLine.recordType: item = ScriptLine(order: 0, speaker: nil, text: "")
            case StagePlacement.recordType: item = StagePlacement(name: "", kind: .cast, area: .stage, x: 0.5, y: 0.5)
            case CueHistory.recordType: item = CueHistory(title: "", detail: "")
            case Comment.recordType: item = Comment(text: "")
            case CueCheck.recordType: item = CueCheck()
            case Notice.recordType: item = Notice(title: "", body: "")
            case NoticeRead.recordType: item = NoticeRead()
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

        // 부모 목록에도 직접 넣는다. 자식 쪽만 이으면 부모 목록(파트.큐 등)을 보는 화면이 늦게 바뀐다
        func addIfMissing<T: PersistentModel>(_ child: T, to list: inout [T]?) {
            if !(list ?? []).contains(child) { list = (list ?? []) + [child] }
        }

        var found = true
        switch item {
        case let scene as ShowScene:
            scene.production = parent(CloudKey.productionID, as: Production.self, found: &found)
            if let production = scene.production { addIfMissing(scene, to: &production.scenes) }
        case let trigger as Trigger:
            trigger.scene = parent(CloudKey.sceneID, as: ShowScene.self, found: &found)
            if let scene = trigger.scene { addIfMissing(trigger, to: &scene.triggers) }
        case let part as Part:
            part.production = parent(CloudKey.productionID, as: Production.self, found: &found)
            if let production = part.production { addIfMissing(part, to: &production.parts) }
        case let cue as Cue:
            cue.trigger = parent(CloudKey.triggerID, as: Trigger.self, found: &found)
            cue.part = parent(CloudKey.partID, as: Part.self, found: &found)
            if let trigger = cue.trigger { addIfMissing(cue, to: &trigger.cues) }
            if let part = cue.part { addIfMissing(cue, to: &part.cues) }
        case let member as Member:
            member.production = parent(CloudKey.productionID, as: Production.self, found: &found)
            let partIDs = record.uuids(CloudKey.partIDs)
            let parts = partIDs.compactMap { findModel($0) as? Part }
            member.parts = parts
            if parts.count < partIDs.count { found = false }
        case let history as CueHistory:
            history.cue = parent(CloudKey.cueID, as: Cue.self, found: &found)
            if let cue = history.cue { addIfMissing(history, to: &cue.histories) }
        case let comment as Comment:
            // 작성자 · 원래 댓글은 없을 수도 있다 (적혀 있지 않으면 부모 없음이 맞음)
            comment.cue = parent(CloudKey.cueID, as: Cue.self, found: &found)
            comment.author = parent(CloudKey.authorID, as: Member.self, found: &found)
            comment.parent = parent(CloudKey.parentID, as: Comment.self, found: &found)
            if let cue = comment.cue { addIfMissing(comment, to: &cue.comments) }
            if let author = comment.author { addIfMissing(comment, to: &author.comments) }
            if let original = comment.parent { addIfMissing(comment, to: &original.replies) }
        case let check as CueCheck:
            check.cue = parent(CloudKey.cueID, as: Cue.self, found: &found)
            check.member = parent(CloudKey.memberID, as: Member.self, found: &found)
            if let cue = check.cue { addIfMissing(check, to: &cue.checks) }
            if let member = check.member { addIfMissing(check, to: &member.checks) }
        case let notice as Notice:
            // 보낸 사람 · 받을 파트 · 받을 사람은 없을 수도 있다 (둘 다 비면 전체 공지)
            notice.production = parent(CloudKey.productionID, as: Production.self, found: &found)
            notice.author = parent(CloudKey.authorID, as: Member.self, found: &found)
            notice.targetPart = parent(CloudKey.targetPartID, as: Part.self, found: &found)
            notice.targetMember = parent(CloudKey.targetMemberID, as: Member.self, found: &found)
            if let production = notice.production { addIfMissing(notice, to: &production.notices) }
            if let author = notice.author { addIfMissing(notice, to: &author.notices) }
        case let read as NoticeRead:
            read.notice = parent(CloudKey.noticeID, as: Notice.self, found: &found)
            read.member = parent(CloudKey.memberID, as: Member.self, found: &found)
            if let notice = read.notice { addIfMissing(read, to: &notice.reads) }
            if let member = read.member { addIfMissing(read, to: &member.noticeReads) }
        case let line as ScriptLine:
            line.scene = parent(CloudKey.sceneID, as: ShowScene.self, found: &found)
            if let scene = line.scene { addIfMissing(line, to: &scene.scriptLines) }
        case let placement as StagePlacement:
            // 최초 상태 배치면 공연 id, 장면 배치면 장면 id 하나만 적혀 있다
            placement.production = parent(CloudKey.productionID, as: Production.self, found: &found)
            placement.scene = parent(CloudKey.sceneID, as: ShowScene.self, found: &found)
            if let production = placement.production { addIfMissing(placement, to: &production.initialPlacements) }
            if let scene = placement.scene { addIfMissing(placement, to: &scene.placements) }
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
