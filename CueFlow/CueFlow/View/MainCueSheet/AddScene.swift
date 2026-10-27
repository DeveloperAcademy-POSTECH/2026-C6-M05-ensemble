//
//  AddScene.swift
//  CueFlow
//
//  Created by 김나현 on 10/12/26.
//

import SwiftUI

struct AddScene: View {
    // 내용을 입력하고 Enter를 눌렀을 때 할 일 (씬 내용, 종류)
    var onSave: (String, SceneKind) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var kind: SceneKind
    @FocusState private var isTitleFocused: Bool

    // 새로 만들 때는 빈 칸으로, 수정할 때는 원래 값을 채워서 연다
    init(title: String = "", kind: SceneKind = .scene,
         onSave: @escaping (String, SceneKind) -> Void = { _, _ in }) {
        _title = State(initialValue: title)
        _kind = State(initialValue: kind)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            kindMenu
            titleSection
        }
        .padding(16)
        .frame(width: 240)
        .onAppear { isTitleFocused = true }
    }
}

extension AddScene {
    // 왼쪽 위 "씬 ▾" → 누르면 씬 / 넘버 / 전환 선택
    private var kindMenu: some View {
        Menu {
            Picker("종류", selection: $kind) {
                ForEach(SceneKind.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            kindMenuLabel
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var kindMenuLabel: some View {
        HStack(spacing: 4) {
            Text(kind.rawValue)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .font(.subheadline)
        .foregroundStyle(Color.neutral700)
        .padding(.horizontal, 10)
        .frame(height: 22)
        .background(Color.neutral200, in: .capsule)
    }

    // "내용" 제목 + 입력칸
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내용")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.neutral800)
            titleField
        }
    }

    // 입력칸
    private var titleField: some View {
        TextField("", text: $title, prompt: .popoverPlaceholder)
            .focused($isTitleFocused)
            .onSubmit { addScene() }
            .popoverInputStyle()
    }
}

extension AddScene {
    // 내용이 비어 있으면 아무것도 안 함
    private func addScene() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        onSave(trimmedTitle, kind)
        dismiss()
    }
}

#Preview {
    AddScene()
        .padding()
        .background(Color.neutral100)
}
