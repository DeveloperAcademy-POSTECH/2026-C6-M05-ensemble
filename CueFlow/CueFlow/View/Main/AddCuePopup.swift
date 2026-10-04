//
//  AddCuePopup.swift
//  CueFlow
//
//  칸의 + Add new를 누르면 뜨는 큐 입력 팝업 (피그마 로우파이_4차 · 큐/트리거 입력)
//  파트·씬은 누른 칸으로 정해지고, 큐 내용 · 상수/하수 · 트리거만 입력한다.
//  같은 씬에 같은 글자의 트리거가 있으면 그 트리거에 붙는다 (CueStore.addCue).
//

import SwiftUI

struct AddCuePopup: View {
    let partID: Part.ID
    let sceneID: ShowScene.ID
    var onDone: () -> Void

    @Environment(CueStore.self) private var store
    @State private var action = ""
    @State private var triggerText = ""
    @State private var position: StageSide?
    @FocusState private var focus: Field?

    private enum Field { case cue, trigger }

    private var trimmedAction: String { action.trimmingCharacters(in: .whitespaces) }
    private var trimmedTrigger: String { triggerText.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedAction.isEmpty && !trimmedTrigger.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                positionMenu
            }

            label("큐")
                .padding(.top, 22)
            inputBox(canSubmit: !trimmedAction.isEmpty, submit: { focus = .trigger }) {
                TextField("내용을 입력하세요.", text: $action)
                    .focused($focus, equals: .cue)
                    .onSubmit { focus = .trigger }   // 엔터 = 트리거 칸으로
            }

            label("트리거")
                .padding(.top, 16)
            inputBox(canSubmit: canSave, submit: save) {
                TextField("내용을 입력하세요.", text: $triggerText)
                    .focused($focus, equals: .trigger)
                    .onSubmit(save)                  // 엔터 = 저장
            }
        }
        .padding(17)
        .frame(width: 243)
        .defaultFocus($focus, .cue)
    }

    private func save() {
        guard canSave else { return }
        onDone()
        store.addCue(sceneID: sceneID, triggerText: trimmedTrigger, partID: partID,
                     action: trimmedAction, position: position)
    }

    // MARK: - 부품

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(hex: 0x111827))
            .padding(.bottom, 6)
    }

    // 회색 입력칸 + 오른쪽 ↵ 버튼 (입력이 차면 진해짐)
    private func inputBox(canSubmit: Bool, submit: @escaping () -> Void,
                          @ViewBuilder field: () -> some View) -> some View {
        HStack(spacing: 6) {
            field()
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            Button(action: submit) {
                Image(systemName: "arrow.turn.down.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 21, height: 21)
                    .background(Color(hex: canSubmit ? 0x2E2E2E : 0xAAAAAA), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
        .padding(.leading, 15)
        .padding(.trailing, 6)
        .frame(height: 32)
        .background(Color(hex: 0xD9D9D9), in: .rect(cornerRadius: 6))
    }

    // 상수 / 하수 / 없음
    private var positionMenu: some View {
        Menu {
            ForEach(StageSide.allCases, id: \.self) { side in
                Button(side.rawValue) { position = side }
            }
            Divider()
            Button("없음") { position = nil }
        } label: {
            HStack(spacing: 4) {
                Text(position?.rawValue ?? "위치")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0x111827))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7))
                    .foregroundStyle(Color(hex: 0x111827))
            }
            .padding(.horizontal, 10)
            .frame(height: 21)
            .background(Color(hex: 0xD9D9D9), in: .capsule)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
    }
}

#Preview {
    let store = CueStore.sample()
    AddCuePopup(partID: store.parts[0].id, sceneID: store.scenes[0].id) {}
        .environment(store)
}
