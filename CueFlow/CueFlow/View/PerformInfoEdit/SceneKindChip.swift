//
//  SceneKindChip.swift
//  CueFlow
//
//  Created by 김나현 on 10/16/26.
//

import SwiftUI

// 씬 · 넘버 · 전환 칩)
struct SceneKindChip: View {
    let kind: SceneKind
    var isSelected = false
    var body: some View {
        Text(kind.rawValue)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.neutral900)
            .frame(width: 62, height: 36)
            .background(kind.chipColor.opacity(0.5), in: .capsule)
            .overlay(selectedBorder)
    }

    private var selectedBorder: some View {
        Capsule()
            .strokeBorder(Color.brandPrimary, lineWidth: isSelected ? 1 : 0)
    }
}

// 칩 더블클릭 팝오버: 씬 · 넘버 · 전환 중 고르기
struct SceneKindPicker: View {
    let selected: SceneKind
    var onSelect: (SceneKind) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SceneKind.allCases, id: \.self) { kindButton($0) }
        }
        .padding(12)
    }

    private func kindButton(_ kind: SceneKind) -> some View {
        Button { onSelect(kind) } label: {
            SceneKindChip(kind: kind, isSelected: kind == selected)
        }
        .buttonStyle(.plain)
    }
}

extension SceneKind {
    // 칩 배경색
    var chipColor: Color {
        switch self {
        case .scene: .brandPrimarySubtle
        case .number: .brandPrimaryDisabled
        case .transition: .brandPrimaryHover
        }
    }
}
