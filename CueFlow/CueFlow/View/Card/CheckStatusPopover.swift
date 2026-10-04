//
//  CheckStatusPopover.swift
//  CueFlow
//
//  B(셀리나) 담당 — ✓ 확인 현황
//  카드 오른쪽 아래 "✓ 25" 버튼을 누르면, 이 큐를 누가 확인했고 누가 아직 안 했는지 보여 준다.
//  데이터는 CueStore.checkStatus(of:)에서 꺼내 쓴다.
//

import SwiftUI

// MARK: - 카드에 들어가는 "✓ 숫자" 버튼

struct CheckCountButton: View {
    @Environment(CueStore.self) private var store
    let cueID: Cue.ID
    var currentMemberID: Member.ID? = nil   // 넣으면 팝오버에 "확인했어요" 버튼이 생김

    @State private var isPresented = false

    var body: some View {
        let count = store.cue(cueID)?.checkedBy.count ?? 0

        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 12, height: 12)
                    .background(.white, in: .circle)
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2F3437))
            }
            .padding(.leading, 5)
            .padding(.trailing, 8)
            .frame(minWidth: 42, minHeight: 22)
            .background(Color(hex: 0xF2F2F2), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            CheckStatusPopover(cueID: cueID, currentMemberID: currentMemberID)
        }
    }
}

// MARK: - 확인 현황 팝오버

struct CheckStatusPopover: View {
    @Environment(CueStore.self) private var store
    let cueID: Cue.ID
    var currentMemberID: Member.ID? = nil

    var body: some View {
        let status = store.checkStatus(of: cueID)
        let total = status.checked.count + status.unchecked.count

        VStack(alignment: .leading, spacing: 12) {
            header(checked: status.checked.count, total: total)
            progressBar(ratio: total == 0 ? 0 : Double(status.checked.count) / Double(total))

            memberSection(title: "확인함", members: status.checked, isChecked: true,
                          emptyText: "아직 확인한 사람이 없어요")

            if !status.unchecked.isEmpty {
                Divider()
                memberSection(title: "미확인", members: status.unchecked, isChecked: false,
                              emptyText: "")
            }

            if let currentMemberID {
                toggleButton(isChecked: status.checked.contains { $0.id == currentMemberID },
                             memberID: currentMemberID)
            }
        }
        .padding(14)
        .frame(width: 220, alignment: .leading)
    }

    // "확인 현황            3/6명"
    private func header(checked: Int, total: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("확인 현황")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: 0x111827))
            Spacer()
            Text(checked == total && total > 0 ? "모두 확인" : "\(checked)/\(total)명")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: 0x6B7280))
        }
    }

    private func progressBar(ratio: Double) -> some View {
        Capsule()
            .fill(Color(hex: 0xEFEFEF))
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(Color(hex: 0x2E2E2E))
                        .frame(width: geo.size.width * ratio)
                }
            }
            .animation(.easeOut(duration: 0.2), value: ratio)
    }

    private func memberSection(title: String, members: [Member], isChecked: Bool,
                               emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) \(members.count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(hex: 0x7A7A7A))

            if members.isEmpty {
                Text(emptyText)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0x9CA3AF))
            } else {
                ForEach(members) { member in
                    MemberRow(member: member,
                              partName: store.part(member.partID)?.name ?? "",
                              isChecked: isChecked,
                              isMe: member.id == currentMemberID)
                }
            }
        }
    }

    private func toggleButton(isChecked: Bool, memberID: Member.ID) -> some View {
        Button {
            store.toggleCheck(cueID: cueID, memberID: memberID)
        } label: {
            Text(isChecked ? "확인 취소" : "확인했어요")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isChecked ? Color(hex: 0x2E2E2E) : .white)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(isChecked ? Color.white : Color(hex: 0x2E2E2E), in: .rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(isChecked ? Color(hex: 0xC9CED6) : .clear, lineWidth: 1))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 팀원 한 줄: (이니셜) 이름  파트  ✓

private struct MemberRow: View {
    let member: Member
    let partName: String
    let isChecked: Bool
    var isMe = false

    var body: some View {
        HStack(spacing: 8) {
            Text(String(member.name.prefix(1)))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(hex: 0x7A7A7A))
                .frame(width: 22, height: 22)
                .background(Color(hex: 0xCFCFCF), in: .circle)

            Text(isMe ? "\(member.name) (나)" : member.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isChecked ? Color(hex: 0x2E2E2E) : Color(hex: 0x9CA3AF))

            Text(partName)
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: 0x9CA3AF))

            Spacer(minLength: 0)

            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(hex: 0x2E2E2E))
            }
        }
        .opacity(isChecked ? 1 : 0.85)
    }
}

// MARK: - 미리보기

#Preview("확인 현황 팝오버") {
    let store = CueStore.sample()
    CheckStatusPopover(cueID: store.cues[1].id,
                       currentMemberID: store.members.first { $0.name == "셀리나" }?.id)
        .environment(store)
}

#Preview("✓ 버튼") {
    let store = CueStore.sample()
    CheckCountButton(cueID: store.cues[1].id)
        .padding(40)
        .background(Color(hex: 0xD9D9D9))
        .environment(store)
}
