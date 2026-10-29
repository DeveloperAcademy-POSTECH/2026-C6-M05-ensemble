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

    @Environment(\.closeAppPopover) private var closePopover   // 저장하면 팝오버 닫기
    @State private var title: String
    @State private var kind: SceneKind
    @FocusState private var isTitleFocused: Bool
    @State private var isPickingKind = false   // 종류 고르는 팝오버가 열려 있는지

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
        .onAppear { isTitleFocused = true }
    }
}

extension AddScene {
    // 왼쪽 위 "씬 ▾" → 누르면 씬 / 넘버 / 전환 고르는 팝오버
    private var kindMenu: some View {
        Button { isPickingKind = true } label: { kindMenuLabel }
            .buttonStyle(.plain)
            .fixedSize()
            .appPopover(isPresented: $isPickingKind, width: nil) {
                PopoverCheckList(items: SceneKind.allCases, selected: kind, title: \.rawValue) { kind = $0 }
            }
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
        closePopover()
    }
}

#Preview {
    AddScene()
        .popoverStyle()
        .padding(60)
}
