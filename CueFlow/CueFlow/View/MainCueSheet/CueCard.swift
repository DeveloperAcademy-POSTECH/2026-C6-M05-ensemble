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
    var onShowHistory: () -> Void = {}   // 우클릭 → History
    var onShowUnread: () -> Void = {}    // 우클릭 → 미확인 수정사항
    var isSelected = false                       // 선택된 카드인지 (테두리가 파트 accent 색)
    var onSelect: (Bool) -> Void = { _ in }      // 카드를 눌렀을 때 (true = shift 누른 채)
    @State private var isEditingCue = false      // 큐 수정 팝오버가 열려 있는지
    @State private var isPickingPosition = false  // 위치 고르는 팝오버가 열려 있는지
    @State private var isShowingMenu = false      // 우클릭 메뉴 팝오버가 열려 있는지
    @State private var isShowingComments = false
    @State private var isShowingChecks = false
    @Environment(\.myUserID) private var myUserID
    @Environment(\.modelContext) private var modelContext   // 큐를 지울 곳
    
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            cueHeader
            cueButtons
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isSelected ? partColor.accent : partColor.background, lineWidth: isSelected ? 1.5 : 1))
        .contentShape(.rect)
        .onTapGesture(count: 2) { isEditingCue = true }   // 더블클릭하면 수정 팝오버
        .highPriorityGesture(TapGesture().modifiers(.shift).onEnded { onSelect(true) })   // Shift+클릭 = 선택에 추가
        .onTapGesture { onSelect(false) }                                                // 그냥 클릭 = 이 카드만 선택
        .appPopover(isPresented: $isEditingCue, edge: .trailing) { cueEditor }
        .onRightClick { isShowingMenu = true }   // 우클릭하면 메뉴 팝오버
        .appPopover(isPresented: $isShowingMenu, edge: .trailing, width: nil) { cueMenu }
        .onChange(of: cue.position) { recordPositionChange(from: $0, to: $1) }
    }
}

// 우클릭 메뉴: 큐 수정하기 · History / 복사하기 · 붙여넣기 / 삭제하기

extension CueCard {
    private var cueMenu: some View {
        PopoverMenu {
            PopoverMenuItem("큐 수정하기") { isEditingCue = true }   // 더블클릭과 같은 수정 팝오버
            PopoverMenuItem("History", action: onShowHistory)       // 오른쪽 History 사이드바 열기
            PopoverMenuItem("미확인 수정사항", action: onShowUnread)
            PopoverMenuDivider()
            PopoverMenuItem("복사하기") { }
            PopoverMenuItem("붙여넣기") { }
            PopoverMenuDivider()
            PopoverMenuItem("삭제하기") { modelContext.deleteCue(cue) }
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
            .font(.callout.weight(.medium))
            .foregroundStyle(partColor.number)
            .frame(width: 23, height: 23)
            .background(partColor.background, in: .circle)
            .contentShape(.circle)
    }
    
    // 언제 실행하는지 (예: 코우 - "너 나가!" 대사 종료 후)
    private var triggerText: some View {
        Text(cue.trigger?.text ?? "")
            .font(.body)
            .foregroundStyle(Color.neutral700)
            .fixedSize(horizontal: false, vertical: true)   // 길면 다음 줄로
    }
    
    // 무엇을 하는지 (예: 정원 전화 받으며 퇴장)
    private var cueTitleText: some View {
        Text(cue.title)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.neutral900)
            .fixedSize(horizontal: false, vertical: true)   // 길면 다음 줄로
    }
    
    // 위치 태그: 누르면 상수 · 하수 · 무대 · 콘솔 고르는 팝오버 (피그마 무대위치)
    private var positionTag: some View {
        Button { isPickingPosition = true } label: { positionTagLabel }
            .buttonStyle(.plain)
            .fixedSize()
            .appPopover(isPresented: $isPickingPosition, width: nil) {
                PopoverCheckList(items: CuePosition.allCases, selected: cue.position, title: \.rawValue) { cue.position = $0 }
            }
    }
    
    // 태그 생김새 (원래 positionTag에 있던 모양 그대로)
    private var positionTagLabel: some View {
        Text(cue.position.rawValue)
            .font(.callout.weight(.medium))
            .foregroundStyle(partColor.number)
            .padding(.horizontal, 5)
            .frame(height: 23)
            .background(partColor.background, in: .capsule)
    }
    
    // 💬 댓글 수 · ✓ 확인한 사람 수
    private var cueButtons: some View {
        HStack(spacing: 6) {
            commentButton
            checkButton
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var commentButton: some View {
        Button { isShowingComments = true } label: {
            HStack(spacing: 2) {
                Image(systemName: "message")
                    .font(.system(size: 8, weight: .semibold))
                Text("\(cue.comments?.count ?? 0)")
            }
            .countPill(background: Color.neutral100)
        }
        .buttonStyle(.plain)
        .appPopover(isPresented: $isShowingComments, width: 260) { CueCommentPopover(cue: cue) }
    }

    // 내가 확인했으면 파트색, 아니면 회색
    private var checkButton: some View {
        Button { isShowingChecks = true } label: {
            HStack(spacing: 3) {
                checkCircle
                Text("\(cue.checks?.count ?? 0)")
            }
            .countPill(background: cue.check(byUserID: myUserID) == nil ? Color.neutral100 : partColor.background)
        }
        .buttonStyle(.plain)
        .appPopover(isPresented: $isShowingChecks, width: 280) { CueCheckPopover(cue: cue) }
    }

    private var checkCircle: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 7, weight: .bold))
            .frame(width: 13, height: 13)
            .background(.white, in: .circle)
    }
    
    // 더블클릭했을 때 뜨는 수정 팝오버 (원래 값이 채워진 채로)
    private var cueEditor: some View {
        AddCueCardInfo(triggerText: cue.trigger?.text ?? "", cueTitle: cue.title, position: cue.position, production: cue.part?.production, partName: cue.part?.name) {
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
        cue.addHistory(title, detail: "\(CurrentEditor.name)님의 수정", before: before, after: after)
    }
    
    // 위치가 바뀌면 (카드 태그 · 수정 팝오버 둘 다) "하수 → 상수로 변경" 기록
    private func recordPositionChange(from old: CuePosition, to new: CuePosition) {
        cue.addHistory("위치 변경", detail: "\(CurrentEditor.name)님이 \(old.rawValue) → \(new.rawValue)로 변경")
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
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.neutral800)
            .padding(.horizontal, 7)
            .frame(minWidth: 40, minHeight: 23)
            .background(background, in: .capsule)
            .contentShape(.capsule)
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
