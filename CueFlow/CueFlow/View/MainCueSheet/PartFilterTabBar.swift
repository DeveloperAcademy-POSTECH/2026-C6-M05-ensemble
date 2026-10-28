//
//  PartFilterTabBar.swift
//  CueFlow
//
//  Created by 김나현 on 10/9/26.
//

import SwiftUI
import SwiftData

struct PartFilterTabBar: View {
    let parts: [Part]              // 보여줄 파트들 (통합 큐시트 · 리허설 모드에서 넘겨줌)
    @Binding var selectedPart: Part?
    var isCompact = false          // 리허설 모드처럼 좁은 곳: 글씨 12, 묶음 높이 36
    
    // 위에서부터 순서대로
    private var sortedParts: [Part] {
        parts.sorted { $0.order < $1.order }
    }
    
    @State private var hoveredChipTitle: String?
    @Namespace private var chipNamespace   // 미끄러지는 선택 캡슐의 이름표
    
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
        HStack(spacing: 0) {
            allPartsChip
            eachPartChips
        }
        .padding(.horizontal, 6)
        .padding(.vertical, isCompact ? 4.5 : 5.5)
        .background(Color.neutral50, in: .capsule)
        .animation(.snappy, value: selectedPart)   // 선택이 바뀌면 캡슐이 미끄러지듯 이동
    }
    
    // [전체] 칩
    private var allPartsChip: some View {
        partChipButton(title: "전체", isSelected: selectedPart == nil) {
            showAllParts()
        }
    }
    
    // 파트 칩들
    private var eachPartChips: some View {
        ForEach(sortedParts) { part in
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
            .buttonStyle(PartChipButtonStyle(isSelected: isSelected, isHovering: hoveredChipTitle == title, isCompact: isCompact))
            .background { selectedBackground(isSelected) }
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
    
    // 선택된 칩 뒤의 연보라 캡슐. 하나뿐이라 선택이 바뀌면 이 캡슐이 옆으로 미끄러져 옮겨감
    @ViewBuilder
    private func selectedBackground(_ isSelected: Bool) -> some View {
        if isSelected {
            Capsule()
                .fill(Color.brandPrimarySubtle)
                .matchedGeometryEffect(id: "selectedChip", in: chipNamespace)
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
    let isCompact: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isCompact ? 12 : 15, weight: .semibold))
            .foregroundStyle(Color.neutral900)
            .lineLimit(1)
            .padding(.horizontal, isCompact ? 16 : 14)
            .frame(minWidth: 50, minHeight: 27)
            .background(backgroundColor(isPressed: configuration.isPressed), in: .capsule)
            .contentShape(.capsule)
    }
}

extension PartChipButtonStyle {
    // 배경색: 선택된 칩은 미끄러지는 캡슐이 따로 그리니까 비워 둠. 누르는 중이면 연보라, 마우스만 올리면 옅은 회색
    private func backgroundColor(isPressed: Bool) -> Color {
        if isSelected { return .clear }
        if isPressed { return .brandPrimarySubtle }
        return isHovering ? .neutral100 : .clear
    }
}
