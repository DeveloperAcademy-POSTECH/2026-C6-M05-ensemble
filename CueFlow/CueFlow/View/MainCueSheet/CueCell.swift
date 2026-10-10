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
    var onAddCue: () -> Void = {}       // Add new를 눌렀을 때 할 일
    
    @State private var isHoveringCell = false   // 마우스가 칸 위에 올라가 있는지
    
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            cueCards
            if isHoveringCell { addNewButton }
        }
        .padding(7)
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(partColor.background.opacity(0.2))
        .overlay(alignment: .leading) { partColorBar }
        .clipShape(.rect(cornerRadius: 5))
        .contentShape(.rect)
        .onHover { isHoveringCell = $0 }
        .animation(.easeOut(duration: 0.15), value: isHoveringCell) // 마우스를 올리면 자연스럽게 칸이 늘어나게 하기 위해 추가함
        .dropDestination(for: String.self) { ids, _ in moveCue(withID: ids.first, before: nil) }
    }
}

extension CueCell {
    // 큐 카드들을 보이는 순서(displayOrder)대로 세로로
    private var cueCards: some View {
        ForEach(sortedCues) { draggableCueCard($0) }
    }
    
    // 끌어서 옮길 수 있는 카드 (다른 카드를 이 위에 놓으면 이 카드 앞으로 감)
    private func draggableCueCard(_ cue: Cue) -> some View {
        CueCard(cue: cue)
            .draggable(cue.id.uuidString)
            .dropDestination(for: String.self) { ids, _ in moveCue(withID: ids.first, before: cue) }
    }
    
    // + Add new
    private var addNewButton: some View {
        Button(action: onAddCue) {
            Label("Add new", systemImage: "plus")
        }
        .buttonStyle(.plain)
        .font(.callout)
        .foregroundStyle(.black)
    }
    
    // 칸 왼쪽의 파트색 세로 막대
    private var partColorBar: some View {
        partColor.background
            .frame(width: 4)
    }
}

extension CueCell {
    // 끌어온 카드를 target 카드 바로 앞으로 옮김 (target이 nil이면 맨 뒤로)
    @discardableResult
    private func moveCue(withID idString: String?, before target: Cue?) -> Bool {
        var reorderedCues = sortedCues
        guard let fromIndex = reorderedCues.firstIndex(where: { $0.id.uuidString == idString }) else { return false }
        let movingCue = reorderedCues.remove(at: fromIndex)
        let toIndex = reorderedCues.firstIndex { $0.id == target?.id } ?? reorderedCues.endIndex
        reorderedCues.insert(movingCue, at: toIndex)
        withAnimation { renumberCues(reorderedCues) }
        return true
    }
    
    // 놓인 순서대로 보이는 위치(displayOrder)를 0, 1, 2 …로 다시 매김 (카드 번호 order는 그대로)
    private func renumberCues(_ orderedCues: [Cue]) {
        for (index, cue) in orderedCues.enumerated() {
            cue.displayOrder = index
        }
    }
}


extension CueCell {
    private var partColor: PartColor {
        part.color
    }
    
    // 드래그로 정한 위치(displayOrder)대로 정렬, 같으면 번호(order) 순
    private var sortedCues: [Cue] {
        cues.sorted { ($0.displayOrder, $0.order) < ($1.displayOrder, $1.order) }
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
    first.displayOrder = 0
    second.displayOrder = 1
    third.displayOrder = 2
    first.trigger = Trigger(text: "오프닝 \"Look Down\" 전주", order: 0)
    second.trigger = Trigger(text: "자베르 - 첫 소절 시작 시", order: 1)
    third.trigger = Trigger(text: "발장 - \"24601\" 대사 후", order: 2)
    
    return CueCell(part: part, cues: [first, second, third])
        .frame(width: 225)
        .padding()
        .modelContainer(container)
}
