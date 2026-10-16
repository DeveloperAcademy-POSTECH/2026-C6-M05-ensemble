//
//  SceneRow.swift
//  CueFlow
//
//  Created by 김나현 on 10/16/26.
//

import SwiftUI

// 공연 흐름 한 줄
struct SceneRow: View {
    let scene: ShowScene
    let code: String           // S#1 · N#1 · D#1
    var onDelete: () -> Void

    @State private var isEditingKind = false    // 칩 팝오버가 열려 있는지
    @State private var isEditingTitle = false   // 제목을 고치는 중인지
    @State private var editingTitle = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(spacing: 40) {
            dragHandle
            kindChip
            codeText
            titleText
            Spacer(minLength: 0)
            deleteButton
        }
        .padding(.leading, 33)
        .padding(.trailing, 48)
        .frame(height: 95)
    }
}

// 드래그 손잡이
extension SceneRow {
    // ≡ 버튼
    private var dragHandle: some View {
        VStack(spacing: 2) {
            handleLine
            handleLine
            handleLine
        }
        .padding(10)
        .contentShape(.rect)
        .onHover { updateCursor(isHovering: $0) }
        .draggable(scene.id.uuidString) { dragPreview }
    }

    private var handleLine: some View {
        Capsule()
            .fill(Color.neutral500)
            .frame(width: 12.5, height: 2)
    }

    // 끄는 동안 마우스에 따라다니는 모양
    private var dragPreview: some View {
        HStack(spacing: 16) {
            SceneKindChip(kind: scene.kind)
            Text("\(code)  \(scene.title)")
                .font(.system(size: 17))
                .foregroundStyle(Color.neutral900)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(.white, in: .rect(cornerRadius: 10))
    }

    private func updateCursor(isHovering: Bool) {
        if isHovering {
            NSCursor.openHand.push()
        } else {
            NSCursor.pop()
        }
    }
}

// 칩 · 번호 · 제목 · 삭제

extension SceneRow {
    // 더블클릭하면 종류 고르기 팝오버
    private var kindChip: some View {
        SceneKindChip(kind: scene.kind)
            .contentShape(.capsule)
            .onTapGesture(count: 2) { isEditingKind = true }
            .popover(isPresented: $isEditingKind, arrowEdge: .bottom) {
                SceneKindPicker(selected: scene.kind, onSelect: changeKind(to:))
            }
    }

    private var codeText: some View {
        Text(code)
            .font(.system(size: 17))
            .foregroundStyle(Color.neutral400)
            .frame(width: 36, alignment: .leading)
    }

    // 평소엔 글자, 더블클릭하면 그 자리에서 입력칸
    @ViewBuilder
    private var titleText: some View {
        if isEditingTitle {
            titleField
        } else {
            titleLabel
        }
    }

    private var titleLabel: some View {
        Text(scene.title)
            .font(.system(size: 17))
            .foregroundStyle(Color.neutral900)
            .lineLimit(1)
            .contentShape(.rect)
            .onTapGesture(count: 2) { startTitleEdit() }
    }

    private var titleField: some View {
        TextField("", text: $editingTitle)
            .textFieldStyle(.plain)
            .font(.system(size: 17))
            .foregroundStyle(Color.neutral900)
            .focused($isTitleFocused)
            .onAppear { isTitleFocused = true }
            .onSubmit { finishTitleEdit() }                    // Enter: 저장
            .onExitCommand { isEditingTitle = false }          // Esc: 취소
            .onChange(of: isTitleFocused) { saveIfBlurred() }  // 다른 곳 클릭: 저장
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.neutral300)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// 수정

extension SceneRow {
    private func changeKind(to kind: SceneKind) {
        scene.kind = kind
        isEditingKind = false
    }

    private func startTitleEdit() {
        editingTitle = scene.title
        isEditingTitle = true
    }

    // 비어 있으면 원래 제목 유지
    private func finishTitleEdit() {
        guard isEditingTitle else { return }
        let title = editingTitle.trimmingCharacters(in: .whitespaces)
        if !title.isEmpty { scene.title = title }
        isEditingTitle = false
    }

    private func saveIfBlurred() {
        if !isTitleFocused { finishTitleEdit() }
    }
}
