//
//  SharePopover.swift
//  CueFlow
//
//  큐시트 오른쪽 위 멤버 버튼을 누르면 뜨는 "공유하기" 창 (피그마 Popover · 공유하기).
//  이메일 넣고 [공유하기] → 메일 앱이 초대 링크를 채운 채로 열린다 (우리 앱엔 메일 보낼 서버가 없어서).
//  [링크 복사] → 카톡 등에 직접 붙여 넣기. (링크 복사 버튼은 피그마에 없음 — 디자이너 확인 필요)
//

import SwiftUI
import CloudKit
import AppKit

struct SharePopover: View {
    let production: Production

    @State private var share: CKShare?
    @State private var members: [ShareMember]
    @State private var isLoading: Bool
    @State private var errorText: String?
    @State private var email = ""
    @State private var didCopy = false

    // 미리보기에서는 iCloud 대신 members를 넣어서 모양만 본다
    init(production: Production, previewMembers: [ShareMember]? = nil) {
        self.production = production
        _members = State(initialValue: previewMembers ?? [])
        _isLoading = State(initialValue: previewMembers == nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            emailRow
                .padding(.top, 21)
            accessHeader
                .padding(.top, 39)
            accessList
                .padding(.top, 13)
        }
        .padding(.horizontal, 22)
        .padding(.top, 30)
        .padding(.bottom, 30)
        .frame(width: 420)
        .task { await loadShare() }
    }
}

// 위쪽: 제목 · 이메일

extension SharePopover {
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("공유하기")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.neutral900)
            Text("팀원과 큐시트를 함께 확인하고 편집하세요")
                .font(.caption)
                .foregroundStyle(Color.neutral500)
        }
    }

    // 이메일 입력칸 + [공유하기]
    private var emailRow: some View {
        HStack(spacing: 4) {
            TextField("", text: $email, prompt: Text("이메일 주소를 입력하세요").foregroundStyle(Color.neutral400))
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(Color.neutral800)
                .padding(.horizontal, 15)
                .frame(height: 30)
                .background(.white, in: .rect(cornerRadius: 6))
                .onSubmit(sendEmail)

            Button("공유하기", action: sendEmail)
                .buttonStyle(GrayButtonStyle())
                .frame(width: 75, height: 30)
                .disabled(share == nil || trimmedEmail.isEmpty)
        }
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespaces)
    }
}

// 아래: 접근 권한 · 멤버 목록

extension SharePopover {
    private var accessHeader: some View {
        HStack {
            Text("접근 권한")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.neutral900)
            Spacer()
            Text("멤버 \(members.count)명")
                .font(.caption)
                .foregroundStyle(Color.neutral400)
        }
    }

    private var accessList: some View {
        VStack(spacing: 0) {
            linkRow
            Divider()
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.vertical, 20)
            } else if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(Color.neutral500)
                    .padding(.vertical, 20)
            } else {
                ForEach(members) { member in
                    memberRow(member)
                    if member.id != members.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // 링크가 있는 사람 · 편집 가능 + [링크 복사]
    private var linkRow: some View {
        HStack(spacing: 13) {
            Image(systemName: "network")
                .font(.title3)
                .foregroundStyle(Color.neutral700)
                .frame(width: 25)
            VStack(alignment: .leading, spacing: 3) {
                Text("링크가 있는 사람")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.neutral900)
                Text("링크로 프로젝트에 접근")
                    .font(.caption2)
                    .foregroundStyle(Color.neutral500)
            }
            Spacer()
            Text("편집 가능")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.neutral900)
            Button(didCopy ? "복사됨" : "링크 복사", action: copyLink)
                .buttonStyle(GrayButtonStyle())
                .frame(width: 64, height: 24)
                .disabled(share?.url == nil)
        }
        .padding(.leading, 9)
        .frame(height: 68)
    }

    private func memberRow(_ member: ShareMember) -> some View {
        HStack(spacing: 11) {
            Text(member.initial)
                .font(.callout.weight(.semibold))
                .foregroundStyle(member.isOwner ? Color.white : Color.brandPrimary)
                .frame(width: 25, height: 25)
                .background(member.isOwner ? Color.neutral300 : Color.brandPrimarySubtle, in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(member.isMe ? "\(member.name) (나)" : member.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.neutral900)
                Text(member.isOwner ? "프로젝트 소유자" : "초대된 멤버")
                    .font(.caption2)
                    .foregroundStyle(Color.neutral500)
            }
            Spacer()
            Text(member.isOwner ? "소유자" : "편집 가능")
                .font(.callout)
                .foregroundStyle(Color.neutral700)
        }
        .padding(.leading, 9)
        .frame(height: 58)
    }
}

// 할 일

extension SharePopover {
    // 공유 가져오기 (없으면 만들기)
    private func loadShare() async {
        guard isLoading, !ICloudAccount.isRunningForPreviews else { return }
        do {
            let share = try await CloudShare.share(for: production)
            self.share = share
            members = share.shareMembers
        } catch {
            errorText = "iCloud에 로그인돼 있어야 공유할 수 있어요"
        }
        isLoading = false
    }

    // 메일 앱에 받는 사람 · 초대 링크를 채워서 연다
    private func sendEmail() {
        guard let url = share?.url, !trimmedEmail.isEmpty else { return }
        guard let service = NSSharingService(named: .composeEmail) else { return }
        service.recipients = [trimmedEmail]
        service.subject = "[Cuedit] \(production.title) 큐시트에 초대합니다"
        service.perform(withItems: ["\(production.title) 큐시트에 초대합니다. 아래 링크를 눌러 참여하세요.\n\n\(url.absoluteString)"])
        email = ""
    }

    private func copyLink() {
        guard let url = share?.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        didCopy = true
    }
}

// 회색 바탕 + 진한 글자 (피그마 공유하기 버튼)
private struct GrayButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(isEnabled ? Color.neutral900 : Color.neutral400)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                configuration.isPressed ? Color.neutral300 : Color.neutral200,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    SharePopover(
        production: Production(title: "레미제라블", genre: "뮤지컬", firstShowDate: .now),
        previewMembers: [
            ShareMember(id: "1", name: "Ubin", isMe: true, isOwner: true),
            ShareMember(id: "2", name: "곽선우", isMe: false, isOwner: false),
        ]
    )
}
