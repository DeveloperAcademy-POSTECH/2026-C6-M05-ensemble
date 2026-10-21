//
//  AddCueCardInfo.swift
//  CueFlow
//
//  Created by 김나현 on 10/12/26.
//

import SwiftUI

struct AddCueCardInfo: View {
    // 다 입력하고 Enter를 눌렀을 때 할 일 (트리거 글, 큐 제목, 위치)
    var onSave: (String, String, CuePosition) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var triggerText: String
    @State private var cueTitle: String
    @State private var position: CuePosition
    @FocusState private var focusedField: InputField?
    
    // 새로 만들 때는 빈 칸으로, 수정할 때는 원래 값을 채워서 연다
    init(triggerText: String = "", cueTitle: String = "", position: CuePosition = .sangsu,
         onSave: @escaping (String, String, CuePosition) -> Void = { _, _, _ in }) {
        _triggerText = State(initialValue: triggerText)
        _cueTitle = State(initialValue: cueTitle)
        _position = State(initialValue: position)
        self.onSave = onSave
    }
    // 지금 글자를 치고 있는 칸
    private enum InputField {
        case trigger, cue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            positionMenu
                .frame(maxWidth: .infinity, alignment: .trailing)
            inputSection(title: "트리거", text: $triggerText, field: .trigger)
                .padding(.bottom, 16)
            inputSection(title: "큐", text: $cueTitle, field: .cue)
        }
        .padding(16)
        .frame(width: 240)
        .onAppear { focusedField = .trigger }
    }
}

// 서브뷰

extension AddCueCardInfo {
    // 오른쪽 위 "상수 ▾" → 누르면 상수/하수/무대/콘솔 선택
    private var positionMenu: some View {
        Menu {
            Picker("위치", selection: $position) {
                ForEach(CuePosition.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            positionMenuLabel
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
    
    private var positionMenuLabel: some View {
        HStack(spacing: 4) {
            Text(position.rawValue)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .font(.subheadline)
        .foregroundStyle(Color.neutral700)
        .padding(.horizontal, 10)
        .frame(height: 22)
        .background(Color.neutral200, in: .capsule)
    }
    
    // 제목("트리거" / "큐") + 입력칸
    private func inputSection(title: String, text: Binding<String>, field: InputField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.neutral800)
            inputField(text: text, field: field)
        }
    }
    
    // 입력칸
    private func inputField(text: Binding<String>, field: InputField) -> some View {
        TextField("", text: text, prompt: .popoverPlaceholder)
            .focused($focusedField, equals: field)
            .onSubmit { handleReturn(in: field) }
            .popoverInputStyle()
    }
}

// 동작

extension AddCueCardInfo {
    // 트리거 칸에서 Enter → 큐 칸으로 이동, 큐 칸에서 Enter → 큐 추가
    private func handleReturn(in field: InputField) {
        if field == .trigger {
            moveToCueField()
            return
        }
        addCue()
    }
    
    // 큐 제목이 비어 있으면 아무것도 안 함
    private func addCue() {
        let title = cueTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        onSave(triggerText, title, position)
        dismiss()
    }
    
    // 한글 입력이 끝난 다음에 칸을 옮겨야 트리거 칸 글자가 남는다
    private func moveToCueField() {
        DispatchQueue.main.async {
            focusedField = .cue
        }
    }
}

#Preview {
    AddCueCardInfo()
        .padding()
        .background(Color.neutral100)
}
