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
    @Binding var selectedParts: Set<Part>   // 고른 파트들 (비어 있으면 전체)
    var isCompact = false          // 리허설 모드처럼 좁은 곳: 글씨 12, 묶음 높이 36
    
    // 위에서부터 순서대로
    private var sortedParts: [Part] {
        parts.sorted { $0.order < $1.order }
    }
    
    @State private var hoveredChipTitle: String?
    @Environment(\.colorScheme) private var colorScheme   // 라이트 · 다크에 따라 선택 칩 색이 다름
    
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
        HStack(spacing: 7) {   // 피그마: 칩 사이 7, 바깥 회색 바 없음
            allPartsChip
            eachPartChips
        }
        .animation(.snappy, value: selectedParts)   // 선택이 바뀌면 칩 색이 부드럽게 바뀜
    }
    
    // [전체] 칩
    private var allPartsChip: some View {
        partChipButton(title: "전체", isSelected: selectedParts.isEmpty) {
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
            .buttonStyle(PartChipButtonStyle(isSelected: isSelected, isHovering: hoveredChipTitle == title, isCompact: isCompact, isDark: colorScheme == .dark))
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
        selectedParts.contains(part)
    }
    
    private func showAllParts() {
        selectedParts.selectPartFilter(nil, totalCount: parts.count)
    }
    
    // 누르면 고른 파트에 넣거나 빼기 (여러 개 가능). 전부 고르면 "전체"로
    private func togglePartFilter(_ part: Part) {
        selectedParts.selectPartFilter(part, totalCount: parts.count)
    }
}

// 칩 버튼 스타일
private struct PartChipButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isHovering: Bool
    let isCompact: Bool
    let isDark: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(size: isCompact ? 12 : 15, weight: .semibold))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .padding(.horizontal, isCompact ? 16 : 14)
            .frame(height: isCompact ? 27 : 36)
            .background(backgroundColor(isPressed: configuration.isPressed), in: .capsule)
            .overlay(Capsule().strokeBorder(borderColor))
            .contentShape(.capsule)
    }
}

extension PartChipButtonStyle {
    // 글자: 선택 = brandPrimaryText (라이트 #3019A6 / 다크 #FCFCFD)
    //       나머지 = 라이트 neutral900 #121926 / 다크 neutral400 #A0A0AA
    private var textColor: Color {
        if isSelected { return .brandPrimaryText }
        return isDark ? .neutral400 : .neutral900
    }
    
    // 배경: 선택 = 라이트 neutral25 #FCFCFD / 다크 neutral300 #5C5C63
    //       나머지 = neutral25 (라이트 #FCFCFD / 다크 #2C2C2E), 마우스를 올리거나 누르면 neutral100
    private func backgroundColor(isPressed: Bool) -> Color {
        if isSelected { return isDark ? .neutral300 : .neutral25 }
        return isHovering || isPressed ? .neutral100 : .neutral25
    }
    
    // 테두리: 선택 = 라이트 brandPrimary #6155F5 / 다크 neutral600 #D1D1D6
    //         나머지 = neutral300 (라이트 #CDD5DF / 다크 #5C5C63)
    private var borderColor: Color {
        if isSelected { return isDark ? .neutral600 : .brandPrimary }
        return .neutral300
    }
}

// 파트 필터 고르기 (파트 필터 바 · 메뉴 막대가 같이 씀)
// 전체(nil)면 비우고, 파트면 넣거나 빼기. 전부 고르면 "전체"로
extension Set<Part> {
    mutating func selectPartFilter(_ part: Part?, totalCount: Int) {
        guard let part else {
            removeAll()
            return
        }
        if contains(part) { remove(part) } else { insert(part) }
        if count == totalCount { removeAll() }
    }
}
