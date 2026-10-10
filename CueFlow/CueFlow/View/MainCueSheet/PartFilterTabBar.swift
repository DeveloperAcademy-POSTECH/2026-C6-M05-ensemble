//
//  PartFilterTabBarView.swift
//  CueFlow
//
//  Created by 김나현 on 10/9/26.
//

import SwiftUI
import SwiftData

struct PartFilterTabBar: View {
    @Query(sort: \Part.order) private var parts: [Part]
    @Binding var selectedPart: Part?
    @State private var hoveredChipTitle: String?
    
    var body: some View {
        // 옆으로 밀어서 볼 수 있는 뷰.
        ScrollView(.horizontal, showsIndicators: false) {
            partChipRow
        }
        .scrollClipDisabled()
    }
}

// 서브뷰
extension PartFilterTabBar {
    private var partChipRow: some View {
        HStack(spacing: 5) {
            allPartsChip
            eachPartChips
        }
    }
    
    // [전체] 칩
    private var allPartsChip: some View {
        partChipButton(title: "전체", isSelected: selectedPart == nil) {
            showAllParts()
        }
    }
    
    // 파트 칩들
    private var eachPartChips: some View {
        ForEach(parts) { part in
            partChip(for: part)
        }
    }
    
    // 파트 칩 하나
    private func partChip(for part: Part) -> some View {
        partChipButton(title: part.name, isSelected: isSelectedPart(part)) {
            togglePartFilter(part)
        }
    }
    
    // 누를 수 있는 칩 버튼
    private func partChipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(PartChipButtonStyle(isSelected: isSelected, isHovering: hoveredChipTitle == title))
            .onHover { updateHoveredChip(title: title, isHovering: $0) }
    }
    
    //hover
    private func updateHoveredChip(title: String, isHovering: Bool) {
        if isHovering {
            hoveredChipTitle = title
        } else if hoveredChipTitle == title {
            hoveredChipTitle = nil
        }
    }
}

extension PartFilterTabBar {
    private func isSelectedPart(_ part: Part) -> Bool {
        selectedPart == part
    }
    
    private func showAllParts() {
        selectedPart = nil
    }
    
    
    private func togglePartFilter(_ part: Part) {
        selectedPart = isSelectedPart(part) ? nil : part
    }
}

// 칩 버튼 스타일
private struct PartChipButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isHovering: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(textColor(isPressed: configuration.isPressed))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minWidth: 50, minHeight: 30)
            .background(backgroundColor(isPressed: configuration.isPressed), in: .capsule)
            .overlay(Capsule().strokeBorder(.brandPrimary, lineWidth: 1))
            .contentShape(.capsule)
    }
}

extension PartChipButtonStyle {
    // 배경색: 누름 > 선택 > 마우스 올림 순서로 정해
    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed { return .brandPrimaryPressed }
        if isSelected { return isHovering ? .brandPrimaryHover : .brandPrimary }
        return isHovering ? .brandPrimarySubtle : .white
    }
    
    // 글자색: 배경이 진한 보라면 흰 글씨, 아니면 진한 보라 글씨
    private func textColor(isPressed: Bool) -> Color {
        isSelected || isPressed ? .white : .brandPrimaryText
    }
}

//MARK: 프리뷰를 위한 코드
extension ModelContainer {
    // 메모리에만 있는 임시 저장소 + 기본 파트 5개
    @MainActor static let partPreview: ModelContainer = {
        let container = try! ModelContainer(for: Part.self, configurations: .init(isStoredInMemoryOnly: true))
        for part in Part.makeDefaultParts() {
            container.mainContext.insert(part)
        }
        return container
    }()
}

#Preview {
    @Previewable @State var selectedPart: Part?
    PartFilterTabBar(selectedPart: $selectedPart)
        .padding(30)
        .frame(width: 600)
        .modelContainer(.partPreview)
}
