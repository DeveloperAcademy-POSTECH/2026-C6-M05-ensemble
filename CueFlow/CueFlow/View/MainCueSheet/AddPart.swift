//
//  AddPart.swift
//  CueFlow
//
//  Created by 김나현 on 10/12/26.
//

import SwiftUI

struct AddPart: View {
    // 파트 이름을 입력하고 Enter를 눌렀을 때 할 일
    var onSave: (String) -> Void

    @Environment(\.closeAppPopover) private var closePopover   // 저장하면 팝오버 닫기
    @State private var name: String
    @FocusState private var isNameFocused: Bool

    // 새로 만들 때는 빈 칸으로, 수정할 때는 원래 이름을 채워서 연다
    init(name: String = "", onSave: @escaping (String) -> Void = { _ in }) {
        _name = State(initialValue: name)
        self.onSave = onSave
    }

    var body: some View {
        nameSection
            .onAppear { isNameFocused = true }
    }
}

extension AddPart {
    // "파트" 제목 + 입력칸
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("파트")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.neutral800)
            nameField
        }
    }

    // 입력칸
    private var nameField: some View {
        TextField("", text: $name, prompt: .popoverPlaceholder)
            .focused($isNameFocused)
            .onSubmit { addPart() }
            .popoverInputStyle()
    }
}

extension AddPart {
    // 이름이 비어 있으면 아무것도 안 함
    private func addPart() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        onSave(trimmedName)
        closePopover()
    }
}

#Preview {
    AddPart()
        .popoverStyle()
        .padding(60)
}
