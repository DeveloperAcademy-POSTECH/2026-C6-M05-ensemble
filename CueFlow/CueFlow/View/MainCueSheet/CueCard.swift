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
    @State private var isEditingNumber = false   // 번호 수정 창이 열려 있는지
    @State private var isEditingCue = false      // 큐 수정 팝오버가 열려 있는지
    @State private var isPickingPosition = false  // 위치 고르는 팝오버가 열려 있는지
    @Environment(\.modelContext) private var modelContext   // 큐를 지울 곳
    
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            cueHeader
            buttonSpace
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(partColor.background, lineWidth: 1))
        .contentShape(.rect)
        .onTapGesture(count: 2) { isEditingCue = true }   // 더블클릭하면 수정 팝오버
        .appPopover(isPresented: $isEditingCue, edge: .trailing) { cueEditor }
        .contextMenu {   // 우클릭 메뉴
            Button("삭제", role: .destructive) { modelContext.deleteCue(cue) }
        }
    }
}

extension CueCard {
    // 윗부분: [01] 트리거 / 큐 제목 ……… [상수]
    private var cueHeader: some View {
        HStack(alignment: .top, spacing: 5) {
            cueNumberButton
            cueTexts
            Spacer(minLength: 0)
            positionTag
        }
    }
    
    // 번호 버튼: 누르면 번호를 고치는 작은 창이 뜸
    private var cueNumberButton: some View {
        Button { isEditingNumber = true } label: { cueNumberLabel }
            .buttonStyle(.plain)
            .popover(isPresented: $isEditingNumber, arrowEdge: .bottom) { cueNumberEditor }
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
    
    // 번호 입력 창: 숫자를 입력하고 Enter를 누르면 저장되고 창이 닫힘
    private var cueNumberEditor: some View {
        TextField("번호", value: $cue.order, format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 60)
            .padding(10)
            .onSubmit { isEditingNumber = false }
    }
    
    // 트리거(윗줄) + 큐 제목(아랫줄)
    private var cueTexts: some View {
        VStack(alignment: .leading, spacing: 5) {
            triggerText
            cueTitleText
        }
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
    
    private var buttonSpace: some View {
        Color.clear
            .frame(height: 23)
    }
    
    // 더블클릭했을 때 뜨는 수정 팝오버 (원래 값이 채워진 채로)
    private var cueEditor: some View {
        AddCueCardInfo(triggerText: cue.trigger?.text ?? "", cueTitle: cue.title, position: cue.position, production: cue.part?.production) {
            updateCue(triggerText: $0, cueTitle: $1, position: $2)
        }
    }
    
    // 팝오버에서 Enter를 누르면 이 카드의 값만 바꿈
    private func updateCue(triggerText: String, cueTitle: String, position: CuePosition) {
        cue.title = cueTitle
        cue.position = position
        changeTrigger(to: triggerText)
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
