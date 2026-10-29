//
//  NoticeRecipientField.swift
//  CueFlow
//
//  공지 쓰기의 "보낼 대상" 칸. 이름·파트를 치면 아래에 맞는 목록이 뜨고,
//  고르면 칩으로 들어간다 (줌·컨플루언스 초대 칸처럼). 비워 두면 프로젝트 전체.
//

import SwiftUI

// 보낼 대상: 전체 / 파트 하나 / 사람 한 명
enum NoticeRecipient: Hashable {
    case all
    case part(Part)
    case member(Member)
}

struct NoticeRecipientField: View {
    let production: Production?          // 고른 프로젝트 (없으면 검색 불가)
    @Binding var recipient: NoticeRecipient

    @State private var query = ""
    @FocusState private var isFocused: Bool

    private var allMemberCount: Int { production?.members?.count ?? 0 }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    // 검색어가 이름에 들어간 파트 (화면 순서대로)
    private var matchedParts: [Part] {
        guard !trimmedQuery.isEmpty else { return [] }
        return (production?.parts ?? [])
            .filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
            .sorted { $0.order < $1.order }
    }

    // 검색어가 이름·맡은 일·파트 이름에 들어간 멤버 (이름 순)
    private var matchedMembers: [Member] {
        guard !trimmedQuery.isEmpty else { return [] }
        return (production?.members ?? [])
            .filter { member in
                member.name.localizedCaseInsensitiveContains(trimmedQuery)
                    || member.role.localizedCaseInsensitiveContains(trimmedQuery)
                    || (member.parts ?? []).contains { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
            }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            inputBox

            // 검색어가 있을 때만 결과 목록
            if isFocused && !trimmedQuery.isEmpty {
                results
            }
        }
    }

    // 칸: 고른 대상 칩 또는 검색 입력
    private var inputBox: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)

            switch recipient {
            case .all:
                TextField(
                    production == nil
                        ? "프로젝트를 먼저 선택하세요."
                        : "이름이나 파트로 검색 (비워 두면 프로젝트 전체 멤버 \(allMemberCount)명)",
                    text: $query
                )
                .textFieldStyle(.plain)
                .focused($isFocused)
                .disabled(production == nil)
                .onSubmit(selectFirstResult)   // Enter = 맨 위 결과 고르기
            case .part(let part):
                chip("\(part.name) 파트 (\(part.members?.count ?? 0)명)")
                Spacer()
            case .member(let member):
                chip(member.name)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 49)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    // 고른 대상 칩. ✕를 누르면 다시 전체로
    private func chip(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
            Button {
                recipient = .all
                query = ""
                isFocused = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
            }
            .buttonStyle(.plain)
            .help("대상 지우기")
        }
        .foregroundStyle(Color.brandPrimaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.brandPrimarySubtle, in: Capsule())
    }

    // 검색 결과 목록
    private var results: some View {
        VStack(alignment: .leading, spacing: 0) {
            if matchedParts.isEmpty && matchedMembers.isEmpty {
                Text("'\(trimmedQuery)'에 맞는 파트나 멤버가 없어요.")
                    .foregroundStyle(.secondary)
                    .padding(12)
            }

            if !matchedParts.isEmpty {
                sectionTitle("파트")
                ForEach(matchedParts) { part in
                    resultRow(
                        title: "\(part.name) 파트",
                        detail: "\(part.members?.count ?? 0)명",
                        icon: "person.3"
                    ) {
                        choose(.part(part))
                    }
                }
            }

            if !matchedMembers.isEmpty {
                sectionTitle("개인")
                ForEach(matchedMembers) { member in
                    resultRow(
                        title: member.name,
                        detail: memberDetail(member),
                        icon: "person"
                    ) {
                        choose(.member(member))
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func resultRow(title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(title)
                Text(detail)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // "무대연출 · 조명, 음향"
    private func memberDetail(_ member: Member) -> String {
        let partNames = (member.parts ?? []).map(\.name).joined(separator: ", ")
        return [member.role, partNames].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func choose(_ newRecipient: NoticeRecipient) {
        recipient = newRecipient
        query = ""
        isFocused = false
    }

    private func selectFirstResult() {
        if let part = matchedParts.first {
            choose(.part(part))
        } else if let member = matchedMembers.first {
            choose(.member(member))
        }
    }
}

#Preview {
    @Previewable @State var recipient: NoticeRecipient = .all
    let production = Production(title: "별마루", genre: "뮤지컬", firstShowDate: Date())
    let lighting = Part(name: "조명", order: 0, colorIndex: 3)
    let member = Member(name: "이진환", role: "무대연출")
    production.parts = [lighting]
    production.members = [member]
    member.parts = [lighting]

    return NoticeRecipientField(production: production, recipient: $recipient)
        .frame(width: 977)
        .padding(40)
}
