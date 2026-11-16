//
//  CueCard.swift
//  CueFlow
//
//  Created by 김나현 on 10/10/26.
//
//  큐 카드 하나: 번호 · 트리거 · 큐 제목 · 위치 태그
//

import SwiftUI
import SwiftData

struct CueCard: View {
    @Bindable var cue: Cue   // 카드 안에서 cue의 값을 바꿀 수 있게 (위치 선택용)
    var menuActions = CueCardMenuActions()   // 우클릭 메뉴가 할 일 (CueGrid가 넣어 줌)
    var isSelected = false                       // 선택된 카드인지 (테두리가 파트 accent 색)
    var onSelect: (Bool) -> Void = { _ in }      // 카드를 눌렀을 때 (true = shift 누른 채)
    @State private var isEditingCue = false      // 큐 수정 팝오버가 열려 있는지
    @State private var closeRequest = 0          // 수정 팝오버 바깥 클릭 · Esc 횟수 (입력창에 알려줌)
    @State private var isPickingPosition = false  // 위치 고르는 팝오버가 열려 있는지
    @State private var isShowingMenu = false      // 우클릭 메뉴 팝오버가 열려 있는지
    @State private var isShowingComments = false
    @State private var isShowingChecks = false
    @Environment(\.myUserID) private var myUserID
    @Environment(\.canEditCues) private var canEdit   // 읽기 권한이면 false (#120)
    @Environment(\.modelContext) private var modelContext   // 큐를 지울 곳
    @AppStorage("showsCommentButton") private var showsComments = true   // 보기 > 댓글 표시

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            cueHeader
            cueButtons
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cueCardBackground, in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isSelected ? partColor.accent : partColor.background, lineWidth: isSelected ? 1.5 : 1))
        .contentShape(.rect)
        .onTapGesture(count: 2) { if canEdit { isEditingCue = true } }   // 더블클릭하면 수정 팝오버
        #if os(macOS)   // 아이패드엔 Shift+클릭이 없다 (#156)
        .highPriorityGesture(TapGesture().modifiers(.shift).onEnded { onSelect(true) })   // Shift+클릭 = 선택에 추가
        #endif
        .onTapGesture { onSelect(false) }                                                // 그냥 클릭 = 이 카드만 선택
        .appPopover(isPresented: $isEditingCue, edge: .trailing, onOutsideTap: { closeRequest += 1 }) { cueEditor }   // 바깥 클릭은 입력창이 정함
        .onRightClick { isShowingMenu = true }   // 우클릭하면 메뉴 팝오버
        .appPopover(isPresented: $isShowingMenu, edge: .trailing, width: nil) { cueMenu }
        .onChange(of: cue.position) { recordPositionChange(from: $0, to: $1) }
    }
}

// 큐 카드 우클릭 메뉴가 할 일 (CueGrid가 넣어 줌 → CueCell → CueCard)
struct CueCardMenuActions {
    var cut: (Cue) -> Void = { _ in }
    var copy: (Cue) -> Void = { _ in }
    var paste: (Cue) -> Void = { _ in }          // 이 카드가 있는 칸에 붙이기
    var delete: (Cue) -> Void = { _ in }
    var showPriority: (Cue) -> Void = { _ in }   // 이 카드가 있는 씬 열의 우선순위 사이드바
    var showHistory: (Cue) -> Void = { _ in }
}

// 우클릭 메뉴: 수정하기 · 잘라내기 · 복사하기 · 붙여넣기 · 삭제 / 우선순위 사이드바 · History
// 읽기 권한이면 복사하기 · 우선순위 · History만

extension CueCard {
    private var cueMenu: some View {
        PopoverMenu(width: 140) {
            if canEdit {
                PopoverMenuItem("큐 카드 수정") { isEditingCue = true }   // 더블클릭과 같은 수정 팝오버
                PopoverMenuItem("잘라내기", shortcut: .command("X")) { menuActions.cut(cue) }
            }
            PopoverMenuItem("복사하기", shortcut: .command("C")) { menuActions.copy(cue) }
            if canEdit {
                PopoverMenuItem("붙여넣기", shortcut: .command("V")) { menuActions.paste(cue) }
                PopoverMenuItem("삭제", shortcut: .commandDelete) { menuActions.delete(cue) }
            }
            PopoverMenuDivider()
            PopoverMenuItem("우선순위 사이드바") { menuActions.showPriority(cue) }
            PopoverMenuItem("큐 카드 History") { menuActions.showHistory(cue) }
        }
    }
}

extension CueCard {
    // 윗줄: [01] 트리거 ……… [상수] / 아랫줄: 큐 제목 (상수 태그 아래까지 넓게)
    private var cueHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {   // 번호 · 트리거 첫 줄 · 위치 태그 글자 밑선 맞춤
                cueNumberLabel
                triggerText
                Spacer(minLength: 0)
                positionTag
            }
            cueTitleText
                .padding(.leading, 28)   // 트리거 글 시작 위치에 맞춤 (번호 23 + 간격 5)
        }
    }
    
    // 번호 동그라미 생김새 (01, 02 …)
    private var cueNumberLabel: some View {
        Text(cueNumberText)
            .font(.appCallout.weight(.medium))
            .foregroundStyle(partColor.number)
            .frame(width: 23, height: 23)
            .background(partColor.background, in: .circle)
            .contentShape(.circle)
    }
    
    // 언제 실행하는지 (예: 코우 - "너 나가!" 대사 종료 후)
    private var triggerText: some View {
        Text(cue.trigger?.text ?? "")
            .font(.appBody)
            .foregroundStyle(Color.cueTriggerText)
            .fixedSize(horizontal: false, vertical: true)   // 길면 다음 줄로
    }
    
    // 무엇을 하는지 (예: 정원 전화 받으며 퇴장)
    private var cueTitleText: some View {
        Text(cue.title)
            .font(.appBody.weight(.semibold))
            .foregroundStyle(Color.neutral900)
            .fixedSize(horizontal: false, vertical: true)   // 길면 다음 줄로
    }
    
    // 위치 태그: 누르면 상수 · 하수 · 무대 · 콘솔 고르는 팝오버 (피그마 무대위치)
    private var positionTag: some View {
        Button { if canEdit { isPickingPosition = true } } label: { positionTagLabel }
            .buttonStyle(.plain)
            .fixedSize()
            .appPopover(isPresented: $isPickingPosition, width: nil) {
                PopoverCheckList(items: CuePosition.allCases, selected: cue.position, title: \.rawValue) { cue.position = $0 }
            }
    }
    
    // 태그 생김새 (원래 positionTag에 있던 모양 그대로)
    private var positionTagLabel: some View {
        Text(cue.position.rawValue)
            .font(.appCallout.weight(.medium))
            .foregroundStyle(partColor.number)
            .padding(.horizontal, 5)
            .frame(height: 23)
            .background(partColor.background, in: .capsule)
    }
    
    // 💬 댓글 수 · ✓ 확인한 사람 수
    private var cueButtons: some View {
        HStack(spacing: 6) {
            if showsComments { commentButton }   // 보기 > 댓글 표시를 끄면 숨김
            checkButton
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var commentButton: some View {
        Button {
            CommentSeen.markSeen(cue.id)   // 열면 새 댓글 점이 사라짐
            isShowingComments = true
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "message")
                    .font(.app(size: 8, weight: .semibold))
                Text("\(cue.comments?.count ?? 0)")
            }
            .countPill(background: Color.tagBackground)
            .overlay(alignment: .topTrailing) { newCommentDot }
        }
        .buttonStyle(.plain)
        .appPopover(isPresented: $isShowingComments, width: 260) { CueCommentPopover(cue: cue) }
        .onChange(of: isShowingComments) { if !$1 { CommentSeen.markSeen(cue.id) } }   // 열어 둔 사이 온 댓글도 읽은 것으로
    }
    
    // 마지막으로 댓글 창을 연 뒤에 다른 사람이 단 댓글이 있는지
    private var hasNewComment: Bool {
        let seen = CommentSeen.lastSeen(cue.id)
        return (cue.comments ?? []).contains { comment in
            comment.createdAt > seen && comment.author?.iCloudUserID != myUserID
        }
    }

    // 피그마 새 댓글 알림 점: 5×5, #E20000, 댓글 버튼 오른쪽 위 모서리
    @ViewBuilder
    private var newCommentDot: some View {
        if hasNewComment {
            Circle()
                .fill(Color(red: 226 / 255, green: 0, blue: 0))
                .frame(width: 5, height: 5)
        }
    }

    // 내가 확인했으면 파트색, 아니면 회색
    private var checkButton: some View {
        Button { isShowingChecks = true } label: {
            HStack(spacing: 3) {
                checkCircle
                Text("\(activeCheckCount)")
            }
            .countPill(background: cue.check(byUserID: myUserID) == nil ? Color.tagBackground : partColor.check)
        }
        .buttonStyle(.plain)
        .appPopover(isPresented: $isShowingChecks, width: 280) { CueCheckPopover(cue: cue) }
    }
    
    // 확인한 사람 수 (공유에서 나간 사람이 눌렀던 확인은 빼고, #209)
    private var activeCheckCount: Int {
        guard let production = cue.part?.production else { return cue.checks?.count ?? 0 }
        return (cue.checks ?? []).filter { check in
            check.member.map { ShareRoster.shared.isStillShared($0, in: production) } ?? false
        }.count
    }

    private var checkCircle: some View {
        Image(systemName: "checkmark")
            .font(.app(size: 7, weight: .bold))
            .frame(width: 13, height: 13)
            .foregroundStyle(Color.checkCircleMark)
            .background(Color.checkCircleBackground, in: .circle)
    }
    
    // 더블클릭했을 때 뜨는 수정 팝오버 (원래 값이 채워진 채로)
    private var cueEditor: some View {
        AddCueCardInfo(triggerText: cue.trigger?.text ?? "", cueTitle: cue.title, position: cue.position, scene: cue.trigger?.scene, partName: cue.part?.name, closeRequest: closeRequest) {
            updateCue(triggerText: $0, cueTitle: $1, position: $2)
        }
    }
    
    // 팝오버에서 Enter를 누르면 이 카드의 값만 바꿈
    private func updateCue(triggerText: String, cueTitle: String, position: CuePosition) {
        recordChange("큐 변경", from: cue.title, to: cueTitle)
        recordChange("트리거 변경", from: cue.trigger?.text ?? "", to: triggerText)
        cue.title = cueTitle
        cue.position = position   // 위치 기록은 onChange에서 남김
        changeTrigger(to: triggerText)
    }
    
    // 글이 바뀌었으면 "이전 · 변경" 기록 남기기
    private func recordChange(_ title: String, from before: String, to after: String) {
        guard before != after else { return }
        cue.addHistory(title, detail: "\(cue.editorName)님의 수정", before: before, after: after)
    }
    
    // 위치가 바뀌면 (카드 태그 · 수정 팝오버 둘 다) "하수 → 상수로 변경" 기록
    private func recordPositionChange(from old: CuePosition, to new: CuePosition) {
        cue.addHistory("위치 변경", detail: "\(cue.editorName)님이 \(old.rawValue) → \(new.rawValue)로 변경")
    }
    
    // 트리거 글이 바뀌었을 때: 다른 큐와 같이 쓰는 트리거면 이 큐만 새 트리거로 떼어냄
    private func changeTrigger(to text: String) {
        guard let trigger = cue.trigger, trigger.text != text else { return }
        guard (trigger.cues?.count ?? 0) > 1 else {
            trigger.text = text   // 이 큐 혼자 쓰는 트리거면 글만 바꿈
            return
        }
        let newTrigger = Trigger(text: text, order: trigger.order)   // 같은 씬, 같은 순서 자리에
        modelContext.insert(newTrigger)
        newTrigger.scene = trigger.scene
        cue.trigger = newTrigger
    }
}

// 데이터(컬러 및 큐 우선순위)

extension CueCard {
    // 이 큐가 속한 파트의 색 (파트가 없으면 첫 번째 색)
    private var partColor: PartColor {
        cue.part?.color ?? PartColor.at(0)
    }
    
    // 사용자가 입력한 번호를 두 자리로 (1 → "01")
    private var cueNumberText: String {
        String(format: "%02d", cue.order)
    }
}

// 큐 지우기: 트리거에 이 큐 하나만 있었으면 트리거도 같이 지움 (리허설 목록에 빈 트리거가 남지 않게)
extension ModelContext {
    func deleteCue(_ cue: Cue) {
        guard let trigger = cue.trigger, trigger.cues?.count == 1 else {
            delete(cue)
            return
        }
        delete(trigger)   // 트리거를 지우면 큐도 같이 지워짐
    }
}

// 큐카드 아래 숫자 캡슐
private extension View {
    func countPill(background: Color) -> some View {
        self
            .font(.app(size: 12, weight: .medium))
            .foregroundStyle(Color.neutral800)
            .padding(.horizontal, 7)
            .frame(minWidth: 40, minHeight: 23)
            .background(background, in: .capsule)
            .contentShape(.capsule)
    }
}

// 새 댓글 알림 (댓글 버튼 빨간 점): 이 큐의 댓글 창을 마지막으로 연 때를 이 맥에 기억
// 처음 쓰는 맥은 그때부터 온 댓글만 새 댓글로 본다 (예전 댓글로 점이 한꺼번에 뜨지 않게)
enum CommentSeen {
    private static let baselineKey = "commentSeenBaseline"

    private static func key(_ cueID: UUID) -> String { "commentSeen.\(cueID.uuidString)" }

    static func lastSeen(_ cueID: UUID) -> Date {
        let defaults = UserDefaults.standard
        if let date = defaults.object(forKey: key(cueID)) as? Date { return date }
        if let baseline = defaults.object(forKey: baselineKey) as? Date { return baseline }
        let now = Date.now
        defaults.set(now, forKey: baselineKey)
        return now
    }

    static func markSeen(_ cueID: UUID) {
        UserDefaults.standard.set(Date.now, forKey: key(cueID))
    }
}

#Preview {
    let container = try! ModelContainer(for: Cue.self, configurations: .init(isStoredInMemoryOnly: true))
    let cue = Cue(title: "정원 전화 받으며 퇴장", position: .sangsu, order: 0)
    container.mainContext.insert(cue)
    cue.part = Part(name: "무대", order: 0, colorIndex: 0)
    cue.trigger = Trigger(text: "코우 - \"너 나가!\" 대사 종료 후", order: 0)
    
    return CueCard(cue: cue)
        .frame(width: 208)
        .padding()
        .modelContainer(container)
}
