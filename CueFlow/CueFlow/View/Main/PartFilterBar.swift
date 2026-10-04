//
//  PartFilterBar.swift
//  CueFlow
//
//  B(셀리나) 담당 — 파트 필터 + 파트 추가 (피그마 로우파이_4차 · 메인큐화면 상단 칩)
//  [전체] [무대] [소품] … [+]
//  - 파트 칩을 누르면 그 파트 줄만 보이고, 한 번 더 누르거나 [전체]를 누르면 다시 전체
//  - [+]를 누르면 이름 입력 팝업 → Enter로 새 파트 추가
//

import SwiftUI

struct PartFilterBar: View {
    @Environment(CueStore.self) private var store
    @State private var isAddingPart = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                PartChip(title: "전체", isSelected: store.selectedPartID == nil) {
                    store.selectPart(nil)
                }

                ForEach(store.parts) { part in
                    let isSelected = store.selectedPartID == part.id
                    PartChip(title: part.name, isSelected: isSelected) {
                        // 선택된 칩을 다시 누르면 전체 보기
                        store.selectPart(isSelected ? nil : part.id)
                    }
                }

                PartChip(title: "+", isSelected: false, weight: .medium) {
                    isAddingPart = true
                }
                .help("파트 추가")
                .popover(isPresented: $isAddingPart, arrowEdge: .bottom) {
                    AddPartPopup { isAddingPart = false }
                }
            }
            .animation(.easeOut(duration: 0.15), value: store.selectedPartID)
        }
        .scrollClipDisabled()
    }
}

// MARK: - 칩 하나 (50 × 24)

private struct PartChip: View {
    let title: String
    let isSelected: Bool
    var weight: Font.Weight = .regular
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .medium : weight))
                .foregroundStyle(isSelected ? .white : Color(hex: 0x2E2E2E))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(minWidth: 50, minHeight: 24)
                .background(isSelected ? Color.black : Color.white, in: .rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.clear : Color(hex: 0xCCCCCC), lineWidth: 1)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 파트 이름 입력 팝업

private struct AddPartPopup: View {
    @Environment(CueStore.self) private var store
    let onDone: () -> Void

    @State private var name = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var isDuplicate: Bool { store.parts.contains { $0.name == trimmed } }
    private var canAdd: Bool { !trimmed.isEmpty && !isDuplicate }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("파트 추가")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: 0x111827))

            TextField("파트 이름 (예: 영상)", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFocused)
                .onSubmit(add)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color(hex: 0xF2F2F2), in: .rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isDuplicate ? Color(hex: 0xD64545) : Color(hex: 0xC9CED6), lineWidth: 1)
                }

            HStack {
                Text(isDuplicate ? "이미 있는 파트예요" : "Enter를 누르면 추가돼요")
                    .font(.system(size: 10))
                    .foregroundStyle(isDuplicate ? Color(hex: 0xD64545) : Color(hex: 0x9CA3AF))
                Spacer()
                Button(action: add) {
                    Text("추가")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(canAdd ? .white : Color(hex: 0x7A7A7A))
                        .frame(width: 52, height: 26)
                        .background(canAdd ? Color(hex: 0x2E2E2E) : Color(hex: 0xF2F2F2), in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
            }
        }
        .padding(14)
        .frame(width: 240)
        .onAppear { isFocused = true }
    }

    private func add() {
        guard canAdd else { return }
        store.addPart(name: trimmed)
        store.selectPart(nil)   // 필터 중이었어도 새 줄이 바로 보이도록 전체 보기로
        name = ""
        onDone()
    }
}

#Preview {
    PartFilterBar()
        .padding(30)
        .frame(width: 600)
        .environment(CueStore.sample())
}
