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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            cueHeader
            buttonSpace
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(partColor.background, lineWidth: 1))
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
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(partColor.number)
            .frame(width: 20, height: 20)
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
        VStack(alignment: .leading, spacing: 3) {
            triggerText
            cueTitleText
        }
    }
    
    // 언제 실행하는지 (예: 코우 - "너 나가!" 대사 종료 후)
    private var triggerText: some View {
        Text(cue.trigger?.text ?? "")
            .font(.caption)
            .foregroundStyle(.black.opacity(0.82))
            .lineLimit(1)
    }
    
    // 무엇을 하는지 (예: 정원 전화 받으며 퇴장)
    private var cueTitleText: some View {
        Text(cue.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black.opacity(0.82))
            .lineLimit(1)
    }
    
    // 위치 태그: 누르면 상수 · 하수 · 무대 · 콘솔 중에서 고르는 메뉴가 뜸
    private var positionTag: some View {
        Menu {
            positionPicker
        } label: {
            positionTagLabel
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
    
    // 메뉴 안의 선택지 (지금 고른 위치에 체크 표시가 붙음)
    private var positionPicker: some View {
        Picker("위치", selection: $cue.position) {
            ForEach(CuePosition.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }
    
    // 태그 생김새 (원래 positionTag에 있던 모양 그대로)
    private var positionTagLabel: some View {
        Text(cue.position.rawValue)
            .font(.caption)
            .foregroundStyle(partColor.number)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(partColor.background, in: .capsule)
    }
    
    private var buttonSpace: some View {
        Color.clear
            .frame(height: 17)
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
