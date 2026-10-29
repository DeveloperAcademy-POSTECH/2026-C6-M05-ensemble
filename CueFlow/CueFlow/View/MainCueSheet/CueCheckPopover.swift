//
//  CueCheckPopover.swift
//  CueFlow
//
//  Created by 김나현 on 10/30/26.
//
//  큐카드 ✓ 버튼 → 확인 현황. 확인한 사람은 게이지 칸 · 동그라미가 그 사람 파트 색으로 바뀜
//

import SwiftUI
import SwiftData

struct CueCheckPopover: View {
    let cue: Cue
    @Environment(\.myUserID) private var myUserID
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            gauge
                .padding(.top, 12)
            memberSection(title: "확인함", members: checkedMembers, empty: "아직 확인한 사람이 없어요")
                .padding(.top, 12)
            Color(red: 212 / 255, green: 212 / 255, blue: 213 / 255)   // D4D4D5 (에셋에 없음)
                .frame(height: 1)
                .padding(.vertical, 14)
            memberSection(title: "미확인", members: uncheckedMembers, empty: "모두 확인했어요")
            checkButton
                .padding(.top, 20)
        }
    }
}

// 제목 · 게이지

extension CueCheckPopover {
    private var header: some View {
        HStack {
            Text("확인 현황")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.neutral900)
            Spacer()
            Text("\(checkedMembers.count)/\(allMembers.count)명")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.neutral500)
        }
    }

    // 멤버 한 명당 한 칸, 확인한 칸이 파트 색으로 참
    private var gauge: some View {
        HStack(spacing: 0) {
            ForEach(checkedMembers) { partColor(of: $0) }
            ForEach(uncheckedMembers) { _ in Color.clear }
        }
        .frame(height: 8)
        .background(Color.neutral100)
        .clipShape(.rect(cornerRadius: 4))
    }
}

// 확인함 · 미확인 목록

extension CueCheckPopover {
    private func memberSection(title: String, members: [Member], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) \(members.count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.neutral900)
            if members.isEmpty {
                Text(empty)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.neutral400)
            }
            ForEach(members) { memberRow($0) }
        }
    }

    private func memberRow(_ member: Member) -> some View {
        HStack(spacing: 10) {
            MemberAvatar(name: member.name, size: 28, background: isChecked(member) ? partColor(of: member) : .neutral300, fontSize: 12)
            Text(isMe(member) ? "\(member.name) (나)" : member.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.neutral500)
            Text(member.mainPart?.name ?? "")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.neutral400)
        }
    }

    private var checkButton: some View {
        Button(action: toggleMyCheck) {
            Text(myCheck == nil ? "확인했어요" : "확인 취소")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.neutral700)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(Color.neutral300, in: .rect(cornerRadius: 6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(myUserID == nil)
    }
}

// 데이터

extension CueCheckPopover {
    // 공연 멤버 전부 (파트 순서대로)
    private var allMembers: [Member] {
        (cue.part?.production?.members ?? []).sorted { ($0.mainPart?.order ?? .max) < ($1.mainPart?.order ?? .max) }
    }

    private var checkedMembers: [Member] { allMembers.filter(isChecked) }
    private var uncheckedMembers: [Member] { allMembers.filter { !isChecked($0) } }

    private func isChecked(_ member: Member) -> Bool {
        (cue.checks ?? []).contains { $0.member == member }
    }

    private func isMe(_ member: Member) -> Bool {
        myUserID != nil && member.iCloudUserID == myUserID
    }

    private func partColor(of member: Member) -> Color {
        member.mainPart?.color.accent ?? Color.neutral400
    }

    private var myCheck: CueCheck? { cue.check(byUserID: myUserID) }

    // 내 확인 기록 추가 / 지우기
    private func toggleMyCheck() {
        if let myCheck {
            modelContext.delete(myCheck)
            return
        }
        guard let myUserID, let production = cue.part?.production else { return }
        let check = CueCheck()
        modelContext.insert(check)
        check.cue = cue
        check.member = modelContext.me(in: production, userID: myUserID)
    }
}
