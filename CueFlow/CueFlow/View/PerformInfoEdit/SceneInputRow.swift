//
//  SceneInputRow.swift
//  CueFlow
//
//  Created by 김나현 on 10/16/26.
//

import SwiftUI

// 맨 아래 입력 줄
struct SceneInputRow: View {
    let scenes: [ShowScene]                    // 다음 번호 계산용
    var onAdd: (String, SceneKind) -> Void     // 내용, 종류

    @State private var kind: SceneKind = .scene
    @State private var title = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 40) {
            plusIcon
            kindMenu
            codeText
            HStack(spacing: 8) {
                titleField
                registerButton
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 33)
        .padding(.trailing, 48)
        .frame(height: 95)
    }
}

extension SceneInputRow {
    private var plusIcon: some View {
        Image(systemName: "plus")
            .font(.system(size: 16))
            .foregroundStyle(Color.neutral500)
            .frame(width: 32.5)
    }

    // 새로 추가될 줄 번호: 같은 종류 개수 + 1
    private var codeText: some View {
        Text("\(kind.codePrefix)#\(sameKindCount + 1)")
            .font(.system(size: 17))
            .foregroundStyle(Color.neutral400)
            .frame(width: 36, alignment: .leading)
    }

    private var sameKindCount: Int {
        scenes.filter { $0.kind == kind }.count
    }
}

// 종류 고르기

extension SceneInputRow {
    private var kindMenu: some View {
        Menu {
            kindPicker
        } label: {
            kindMenuLabel
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var kindPicker: some View {
        Picker("종류", selection: $kind) {
            ForEach(SceneKind.allCases, id: \.self) { Text($0.rawValue) }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }

    private var kindMenuLabel: some View {
        HStack(spacing: 4) {
            Text(kind.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.neutral600)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Color.neutral500)
        }
        .frame(width: 62, height: 36)
        .background(Color.neutral100, in: .capsule)
    }
}

// 입력칸 · 등록

extension SceneInputRow {
    private var titleField: some View {
        TextField("", text: $title, prompt: placeholder)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Color.neutral900)
            .focused($isFocused)
            .onSubmit { add() }   // Enter로도 등록
            .padding(.horizontal, 12)
            .frame(width: 254, height: 36)
            .background(Color.neutral50, in: .rect(cornerRadius: 6))
    }

    private var placeholder: Text {
        Text("내용을 입력하세요")
            .foregroundStyle(Color.neutral400)
    }

    private var registerButton: some View {
        Button { add() } label: {
            Text("등록")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brandPrimaryText)
                .frame(width: 60, height: 36)
                .background(Color.brandPrimarySubtle, in: .rect(cornerRadius: 6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // 내용이 비어 있으면 아무것도 안 함. 등록 후 입력칸을 비우고 바로 다음 줄 입력
    private func add() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed, kind)
        title = ""
        isFocused = true
    }
}
