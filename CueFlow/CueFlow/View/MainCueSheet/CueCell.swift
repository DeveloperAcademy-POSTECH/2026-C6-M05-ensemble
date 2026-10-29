//
//  CueCell.swift
//  CueFlow
//
//  Created by 김나현 on 10/11/26.
//
//

import SwiftUI
import SwiftData

struct CueCell: View {
    let part: Part                      // 이 칸이 속한 파트 (칸 색을 정함)
    let cues: [Cue]                     // 이 칸에 들어갈 큐들
    var isHovering = false              // 마우스가 이 칸 위에 있는지 (CueGrid가 알려줌)
    var onAddCue: (String, String, CuePosition) -> Void = { _, _, _ in }   // 팝오버에서 입력을 마치면 할 일
    var onShowHistory: (Cue) -> Void = { _ in }   // 카드 우클릭 → History
    var selectedCueIDs: Set<UUID> = []                   // 선택된 큐 카드들 (CueGrid가 알려줌)
    var onSelectCue: (Cue, Bool) -> Void = { _, _ in }   // 카드를 눌렀을 때 (true = shift)
    @State private var isAddingCue = false          // Add new 팝오버가 열려 있는지
    
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            cueCards
            if isHovering || isAddingCue { addNewButton }
        }
        .padding(7)
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(partColor.background.opacity(0.2))
        .overlay(alignment: .leading) { partColorBar }
        .clipShape(.rect(cornerRadius: 5))
    }
}

extension CueCell {
    // 큐 카드들을 번호 순서대로 세로로
    private var cueCards: some View {
        ForEach(sortedCues) { cueCard($0) }
    }
    
    private func cueCard(_ cue: Cue) -> some View {
        CueCard(
            cue: cue,
            onShowHistory: { onShowHistory(cue) },
            isSelected: selectedCueIDs.contains(cue.id),
            onSelect: { onSelectCue(cue, $0) }
        )
    }
    
    // + Add new
    private var addNewButton: some View {
        Button { isAddingCue = true } label: {
            Label("Add new", systemImage: "plus")
        }
        .buttonStyle(.plain)
        .font(.body.weight(.medium))
        .foregroundStyle(Color.neutral900)
        .appPopover(isPresented: $isAddingCue) {
            AddCueCardInfo(production: part.production, onSave: onAddCue)
        }
    }
    
    // 칸 왼쪽의 파트색 세로 막대
    private var partColorBar: some View {
        partColor.background
            .frame(width: 4)
    }
}

extension CueCell {
    private var partColor: PartColor {
        part.color
    }
    
    // 큐 번호(order) 순서대로
    private var sortedCues: [Cue] {
        cues.sorted { $0.order < $1.order }
    }
}

#Preview {
    let container = try! ModelContainer(for: Cue.self, configurations: .init(isStoredInMemoryOnly: true))
    let part = Part(name: "무대", order: 0, colorIndex: 0)
    let first = Cue(title: "죄수들 노역 위치 입장", position: .sangsu, order: 1)
    let second = Cue(title: "자베르 고지대 등장", position: .stage, order: 2)
    let third = Cue(title: "발장 가석방 서류 받음", position: .hasu, order: 3)
    container.mainContext.insert(part)
    container.mainContext.insert(first)
    container.mainContext.insert(second)
    container.mainContext.insert(third)
    first.part = part
    second.part = part
    third.part = part
    first.trigger = Trigger(text: "오프닝 \"Look Down\" 전주", order: 0)
    second.trigger = Trigger(text: "자베르 - 첫 소절 시작 시", order: 1)
    third.trigger = Trigger(text: "발장 - \"24601\" 대사 후", order: 2)
    
    return CueCell(part: part, cues: [first, second, third])
        .frame(width: 225)
        .padding()
        .modelContainer(container)
}
