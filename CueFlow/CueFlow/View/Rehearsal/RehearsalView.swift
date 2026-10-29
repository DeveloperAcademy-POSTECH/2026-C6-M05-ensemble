//
//  RehearsalView.swift
//  CueFlow
//
//  리허설 모드 (피그마 리허설모드_수정중). 사이드바 없이 창 전체를 쓴다.
//  왼쪽: 대본 / 오른쪽 위: 무대 배치도 / 오른쪽 아래: 큐 목록
//

import SwiftUI

struct RehearsalView: View {
    let production: Production
    let onExit: () -> Void   // "리허설 모드 종료"

    @Environment(ICloudAccount.self) private var iCloudAccount

    // 지금 보고 있는 장면 (공연 흐름 순서에서 몇 번째인지)
    @State private var sceneIndex = 0

    // 지금 큐 = 지금 장면에서 몇 번째 트리거인지 (같은 트리거의 큐는 동시에 실행)
    @State private var triggerIndex = 0

    // 공연 흐름 순서대로 정렬한 장면들
    private var scenes: [ShowScene] {
        (production.scenes ?? []).sorted { $0.order < $1.order }
    }

    private var currentScene: ShowScene? {
        scenes.indices.contains(sceneIndex) ? scenes[sceneIndex] : nil
    }

    // 지금 장면의 트리거 (순서대로)
    private var currentTriggers: [Trigger] {
        (currentScene?.triggers ?? []).sorted { $0.order < $1.order }
    }

    // 지금 큐에 해당하는 대본 줄 (트리거 글로 찾음)
    private var highlightedLineID: UUID? {
        guard currentTriggers.indices.contains(triggerIndex) else { return nil }
        let matches = ScriptCueMatcher.match(
            triggers: currentTriggers, lines: currentScriptLines, castNames: production.castNames
        )
        return matches[currentTriggers[triggerIndex].id]
    }

    // 지금 장면의 대본 (순서대로)
    private var currentScriptLines: [ScriptLine] {
        (currentScene?.scriptLines ?? []).sorted { $0.order < $1.order }
    }

    @State private var isEditingScript = false   // "대본 입력" 창

    // 파트 필터 칩에 보여줄 파트 (화면 순서대로)
    private var parts: [Part] {
        (production.parts ?? []).sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(spacing: 20) {
            header

            HStack(alignment: .top, spacing: 20) {
                RehearsalScriptPanel(lines: currentScriptLines, highlightedLineID: highlightedLineID) {
                    isEditingScript = true
                }
                .frame(width: 372)

                VStack(spacing: 40) {
                    RehearsalStageMap(
                        production: production,
                        scene: currentScene,
                        triggers: currentTriggers,
                        currentTriggerIndex: triggerIndex
                    )
                        .frame(height: 378)

                    RehearsalCueList(
                            sceneCode: currentScene?.code(in: scenes) ?? "",
                            triggers: currentTriggers,
                            parts: parts,
                            currentIndex: Binding(
                                get: { triggerIndex },
                                set: { if !isFollowing { triggerIndex = $0 } }   // 따라가는 중엔 줄을 눌러도 안 넘어감
                            ),
                            canGoPrevious: !isFollowing && (sceneIndex > 0 || triggerIndex > 0),
                            canGoNext: !isFollowing && (sceneIndex < scenes.count - 1 || triggerIndex < currentTriggers.count - 1),
                            onPrevious: goToPreviousCue,
                            onNext: goToNextCue
                        )
                }
            }
        }
        .sheet(isPresented: $isEditingScript) {
            ScriptInputSheet(production: production, currentScene: currentScene)
        }
        // 장면을 직접 바꾸면 그 장면의 첫 큐부터
        .onChange(of: sceneIndex) {
            if !isMovingByCue { triggerIndex = 0 }
            isMovingByCue = false
        }
        // 동기화 모드: 내가 진행 중이면 넘길 때마다 올리고, 따라가는 중이면 받은 곳으로 넘어간다
        .onChange(of: sceneIndex) { publishIfLeading() }
        .onChange(of: triggerIndex) { publishIfLeading() }
        .onChange(of: isFollowing ? syncPosition : nil, initial: true) { _, position in
            if let position { follow(position) }
        }
        // 진행하던 사람이 리허설 화면을 나가면 진행도 끝
        // 리허설 화면이 열려 있는 동안만 진행 위치를 자주 확인한다 (CloudSync)
        .onAppear { RehearsalSync.shared.watchingProductionID = production.id }
        .onDisappear {
            if isLeading { RehearsalSync.shared.stopLeading(productionID: production.id) }
            RehearsalSync.shared.watchingProductionID = nil
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: RehearsalSync.fakeLeaderNotification)) { notification in
            if let step = notification.object as? RehearsalSync.FakeStep { moveFakeLeader(step) }
        }
        #endif
        .padding(.leading, 51)
        .padding(.trailing, 61)
        .padding(.top, 46)
        .padding(.bottom, 45)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // 이전 큐 / 다음 큐로 장면을 넘어갈 때는 onChange에서 첫 큐로 되돌리지 않게
    @State private var isMovingByCue = false

    // 이전 큐: 장면 첫 큐에서 누르면 앞 장면의 마지막 큐로
    private func goToPreviousCue() {
        if triggerIndex > 0 {
            triggerIndex -= 1
        } else if sceneIndex > 0 {
            isMovingByCue = true
            sceneIndex -= 1
            triggerIndex = max(currentTriggers.count - 1, 0)
        }
    }

    // 다음 큐: 장면 마지막 큐에서 누르면 다음 장면의 첫 큐로
    private func goToNextCue() {
        if triggerIndex < currentTriggers.count - 1 {
            triggerIndex += 1
        } else if sceneIndex < scenes.count - 1 {
            isMovingByCue = true
            sceneIndex += 1
            triggerIndex = 0
        }
    }

    // 공연 이름 · 장면 이동 · 종료 버튼
    private var header: some View {
        HStack(spacing: 0) {
            Text(production.title)
                .font(.system(size: 22, weight: .semibold))   // 피그마 22pt (macOS 기본 스타일에 없음)
                .foregroundStyle(Color.neutral900)

            if let syncStatusText {
                syncStatusChip(syncStatusText)
                    .padding(.leading, 14)
            }

            Spacer()

            HStack(spacing: 10) {
                sceneStepper
                scenePicker
            }

            syncMenu
                .padding(.horizontal, 8)

            // TODO: #41 머지 후 .buttonStyle(.tertiary)로 교체
            Button("리허설 모드 종료", action: onExit)
                .buttonStyle(.plain)
                .frame(width: 115, height: 36)
                .foregroundStyle(Color.brandPrimaryText)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    // 피그마 #2B2476 → 색상 표에서 가장 가까운 brandPrimaryText
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.brandPrimaryText, lineWidth: 1)
                }
        }
    }

    // < > 이전/다음 장면
    private var sceneStepper: some View {
        HStack(spacing: 0) {
            stepButton(systemImage: "chevron.left", help: "이전 장면", isEnabled: !isFollowing && sceneIndex > 0) {
                sceneIndex -= 1
            }
            Divider()
            stepButton(systemImage: "chevron.right", help: "다음 장면", isEnabled: !isFollowing && sceneIndex < scenes.count - 1) {
                sceneIndex += 1
            }
        }
        .frame(height: 36)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.neutral300, lineWidth: 1)
        }
    }

    private func stepButton(systemImage: String, help: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 36, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .help(help)
    }

    // "장면  S#3 시장 등장 ⌃⌄" 누르면 장면 목록
    private var scenePicker: some View {
        Menu {
            ForEach(scenes.indices, id: \.self) { index in
                Button(scenes[index].displayName(in: scenes)) {
                    sceneIndex = index
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text("장면")
                    .font(.callout)
                    .foregroundStyle(Color.neutral400)
                Text(currentScene?.displayName(in: scenes) ?? "장면 없음")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.neutral900)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .frame(width: 170, height: 36)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.neutral300, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(isFollowing)
    }
}

// MARK: - 동기화 모드 (#69)

extension RehearsalView {
    private var myID: String? { iCloudAccount.userRecordName }

    // 지금 이 공연을 누가 진행 중인지 (없으면 nil)
    private var syncPosition: RehearsalPosition? {
        RehearsalSync.shared.position(of: production.id)
    }

    private var isLeading: Bool {
        guard let myID, let syncPosition else { return false }
        return syncPosition.leaderID == myID
    }

    // 다른 사람이 진행 중
    private var isLedByOther: Bool {
        syncPosition != nil && !isLeading
    }

    // 다른 사람이 진행 중이면 무조건 따라간다 → 직접 넘기기 잠금
    // (1차. 따라갈지 고르게 할지는 팀과 다시 정하기)
    private var isFollowing: Bool {
        isLedByOther
    }

    // 다른 사람 화면에 보일 내 이름: 이 공연의 멤버 이름, 없으면(공연 만든 사람 등) 맥 사용자 이름
    private var myName: String {
        (production.members ?? []).first { $0.iCloudUserID == myID }?.name ?? NSFullUserName()
    }

    private var syncStatusText: String? {
        guard let syncPosition else { return nil }
        return isLeading ? "내가 진행 중" : "\(syncPosition.leaderName)님 진행 중 · 따라가는 중"
    }

    private func startLeading() {
        guard let myID, let scene = currentScene else { return }
        RehearsalSync.shared.lead(
            productionID: production.id, leaderID: myID, leaderName: myName,
            sceneID: scene.id, triggerID: currentTriggers.indices.contains(triggerIndex) ? currentTriggers[triggerIndex].id : nil
        )
    }

    private func publishIfLeading() {
        if isLeading { startLeading() }
    }

    // 받은 위치로 넘어가기. 장면이나 큐가 아직 이 맥에 안 왔으면 갈 수 있는 데까지만
    private func follow(_ position: RehearsalPosition) {
        guard let newSceneIndex = scenes.firstIndex(where: { $0.id == position.sceneID }) else { return }
        let triggers = sortedTriggers(at: newSceneIndex)
        if newSceneIndex != sceneIndex {
            isMovingByCue = true   // 장면이 바뀌어도 첫 큐로 되돌리지 않게
            sceneIndex = newSceneIndex
        }
        triggerIndex = triggers.firstIndex { $0.id == position.triggerID } ?? 0
    }

    private func sortedTriggers(at index: Int) -> [Trigger] {
        (scenes[index].triggers ?? []).sorted { $0.order < $1.order }
    }

    #if DEBUG
    // 가짜 진행자 한 칸 움직이기. 처음엔 지금 내 화면 위치에서 시작
    private func moveFakeLeader(_ step: RehearsalSync.FakeStep) {
        let sync = RehearsalSync.shared
        guard step != .stop else {
            sync.sendFake(productionID: production.id, sceneID: nil, triggerID: nil)
            return
        }

        var scene = sceneIndex
        var trigger = triggerIndex
        if let base = sync.fakeBase(of: production.id), let index = scenes.firstIndex(where: { $0.id == base.sceneID }) {
            scene = index
            trigger = sortedTriggers(at: index).firstIndex { $0.id == base.triggerID } ?? 0
            switch step {
            case .next:
                if trigger < sortedTriggers(at: scene).count - 1 {
                    trigger += 1
                } else if scene < scenes.count - 1 {
                    scene += 1
                    trigger = 0
                }
            case .previous:
                if trigger > 0 {
                    trigger -= 1
                } else if scene > 0 {
                    scene -= 1
                    trigger = max(sortedTriggers(at: scene).count - 1, 0)
                }
            case .stop:
                break
            }
        }
        guard scenes.indices.contains(scene) else { return }

        let triggers = sortedTriggers(at: scene)
        sync.sendFake(
            productionID: production.id,
            sceneID: scenes[scene].id,
            triggerID: triggers.indices.contains(trigger) ? triggers[trigger].id : nil
        )
    }
    #endif

    // [동기화 모드] 누르면: 내가 진행하기 / 내가 대신 진행하기 / 진행 끝내기
    private var syncMenu: some View {
        Menu {
            if isLeading {
                Button("진행 끝내기") {
                    RehearsalSync.shared.stopLeading(productionID: production.id)
                }
            } else {
                Button(isLedByOther ? "내가 대신 진행하기" : "내가 진행하기", action: startLeading)
            }
        } label: {
            // 피그마 동기화 모드 버튼 130×36 (primary 모양)
            Text("동기화 모드")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 130, height: 36)
                .background(Color.brandPrimary, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(myID == nil)
        .opacity(myID == nil ? 0.4 : 1)
        .help(myID == nil ? "iCloud에 로그인해야 쓸 수 있어요" : "진행하는 사람이 큐를 넘기면 모두의 화면이 같이 넘어가요")
    }

    // 제목 옆 "● 코우님 진행 중 · 따라가는 중"
    private func syncStatusChip(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.brandPrimary)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brandPrimaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(Color.brandPrimarySubtle, in: Capsule())
    }
}

// 흰 바탕 카드 (대본 · 무대 배치 · 큐 목록 공용 틀). 제목이 없으면 위 제목 줄 없이 내용만.
struct RehearsalCard<Content: View>: View {
    var title: String?
    var cornerRadius: CGFloat = 8   // 피그마: 대본 카드 10, 무대 배치 · 큐 목록 8
    @ViewBuilder var content: Content

    init(title: String? = nil, cornerRadius: CGFloat = 8, @ViewBuilder content: () -> Content = { EmptyView() }) {
        self.title = title
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.neutral700)
                    .padding(.horizontal, 22)
                    .frame(height: 54)
                Divider()
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.neutral25, in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.neutral300, lineWidth: 1)
        }
    }
}

#Preview {
    RehearsalView(production: RehearsalPreviewData.production) { }
        .environment(ICloudAccount())
        .frame(width: 1512, height: 932)
}

// 최초 상태 무대 배치가 없을 때 → 무대 배치 빈 화면
#Preview("무대 배치 빈 화면") {
    let production = RehearsalPreviewData.production
    production.initialPlacements = []
    return RehearsalView(production: production) { }
        .environment(ICloudAccount())
        .frame(width: 1512, height: 932)
}
