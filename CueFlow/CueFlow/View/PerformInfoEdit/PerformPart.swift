//
//  PerformPart.swift
//  CueFlow
//
//  Created by 김나현 on 10/16/26.
//

import SwiftUI

struct PerformPart: View {
    @Binding var selectedParts: Set<String>   // 고른 파트 이름들
    @Binding var customParts: [String]   // 추가하기로 직접 만든 파트 이름들
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}

    @State private var isAddingPart = false   // 추가하기 팝오버가 열려 있는지

    var body: some View {
        CreateStepLayout(
            title: "사용할 파트를 선택해주세요",
            subtitle: "한 파트에 여러 명을 배정하고 파트장·담당 역할을 설정합니다.",
            currentStep: 2,
            onPrevious: onPrevious,
            onNext: onNext
        ) {
            partSectionHeader
                .padding(.top, 41)
            partGrid
                .padding(.top, 13)
        }
    }
}

// 파트 선택

extension PerformPart {
    // 파트선택항목 [5개 선택]                [+ 추가하기]
    private var partSectionHeader: some View {
        HStack(spacing: 10) {
            Text("파트선택항목")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.neutral800)
            Text("\(selectedParts.count)개 선택")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.brandPrimaryText)
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(Color.brandPrimarySubtle, in: .capsule)
            Spacer()
            addButton
        }
        .frame(width: 794)
    }

    private var addButton: some View {
        Button { isAddingPart = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 14))
                Text("추가하기")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.brandPrimaryText)
            .frame(width: 110, height: 38)
            .background(Color.brandPrimarySubtle, in: .rect(cornerRadius: 6))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isAddingPart, arrowEdge: .bottom) {
            AddPart(onSave: addCustomPart)
        }
    }

    // 기본 파트 9개 + 직접 추가한 파트 (기타 아이콘)
    private var allOptions: [PartOption] {
        PartOption.all + customParts.map { PartOption(name: $0, icon: PartOption.customIcon) }
    }

    // 4칸씩 줄바꿈, 가로·세로 간격 18
    private var partGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(185), spacing: 18), count: 4),
                  alignment: .leading, spacing: 18) {
            ForEach(allOptions, id: \.self) { partCard($0) }
        }
        .frame(width: 794, alignment: .leading)
    }

    private func partCard(_ part: PartOption) -> some View {
        let isSelected = selectedParts.contains(part.name)
        return Button { toggle(part.name) } label: {
            HStack(spacing: 8) {
                Image(systemName: part.icon)
                    .font(.system(size: 16, weight: .medium))
                Text(part.name)
                    .font(.system(size: 17, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.brandPrimaryText : Color.neutral900)
            .padding(.horizontal, 20)
            .frame(width: 185, height: 66)
            .background(isSelected ? Color.brandPrimarySubtle.opacity(0.2) : Color.white.opacity(0.5),
                        in: .rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.brandPrimary : Color.neutral400, lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // 누르면 선택 ↔ 해제
    private func toggle(_ name: String) {
        if selectedParts.contains(name) {
            selectedParts.remove(name)
        } else {
            selectedParts.insert(name)
        }
    }
    
    // 팝오버에서 Enter: 기타 뒤에 카드 추가 + 바로 선택
    private func addCustomPart(_ name: String) {
        guard !allOptions.contains(where: { $0.name == name }) else { return }   // 이미 있는 이름이면 무시
        customParts.append(name)
        selectedParts.insert(name)
    }
}

#Preview {
    @Previewable @State var selected = Set(Part.defaultNames)
    @Previewable @State var custom: [String] = []
    PerformPart(selectedParts: $selected, customParts: $custom)
        .frame(width: 1512, height: 982)
}
