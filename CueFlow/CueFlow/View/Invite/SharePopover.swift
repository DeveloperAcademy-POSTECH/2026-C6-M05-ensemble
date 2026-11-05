//
//  SharePopover.swift
//  CueFlow
//
//  "공유하기" 창 (피그마 951:10223). 큐시트 오른쪽 위 [공유하기]에서 연다.
//  큐시트 오른쪽 위 멤버 버튼은 참여자 현황(ParticipantsPopover)을 연다.
//  이메일 넣고 [공유하기] → 메일 앱이 초대 링크를 채운 채로 열린다 (우리 앱엔 메일 보낼 서버가 없어서).
//  총 연출자는 멤버 줄 오른쪽 메뉴에서 사람별로 읽기 · 편집 권한을 바꾼다 (#120).
//  "읽기 가능 ⌄" 메뉴의 [링크 복사] → 카톡 등에 직접 붙여 넣기 (피그마엔 버튼이 없어서 메뉴 안에 넣음, #93)
//

import SwiftUI
import CloudKit
import SwiftData
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
        // 팀 팝오버가 사방 20 · 폭 420 · 바탕을 넣어 준다 → 피그마 여백(좌우 22 · 위아래 30)에서 20을 뺀 만큼만
        .padding(.horizontal, 2)
        .padding(.vertical, 10)
        .task { await loadShare() }
    }
}

// 위쪽: 제목 · 이메일

extension SharePopover {
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("공유하기")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.neutral900)
            Text("팀원과 큐시트를 함께 확인하고 편집하세요")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.shareSubText)
        }
    }

    // 이메일 입력칸 + [공유하기]
    private var emailRow: some View {
        HStack(spacing: 4) {
            TextField("", text: $email, prompt: Text("이메일 주소를 입력하세요").foregroundStyle(Color.shareHint))
                .textFieldStyle(.plain)
                .font(.footnote)   // 피그마 10
                .foregroundStyle(Color.neutral800)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Color.surfaceWhite, in: .rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.neutral300, lineWidth: 1)
                }
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
                .font(.system(size: 11))
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

    // 링크가 있는 사람 · 읽기 가능 ⌄ (메뉴: 링크 복사)
    private var linkRow: some View {
        HStack(spacing: 13) {
            Image(systemName: "network")
                .font(.system(size: 18))
                .foregroundStyle(Color.neutral500)
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
            // 팀 결정: 링크로 들어오면 모두 읽기 권한으로 시작 → 권한은 고르지 않고, 메뉴에 링크 복사만
            Menu {
                Label("읽기 가능", systemImage: "checkmark")
                Divider()
                Button(didCopy ? "링크 복사됨" : "링크 복사", action: copyLink)
                    .disabled(share?.url == nil)
            } label: {
                HStack(spacing: 6) {
                    Text("읽기 가능")
                        .font(.system(size: 11.5, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Color.noticeMetaText)
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.leading, 9)
        .frame(height: 68)
    }

    private func memberRow(_ member: ShareMember) -> some View {
        HStack(spacing: 11) {
            Text(member.initial)
                .font(.system(size: member.isOwner ? 14 : 16, weight: .medium))
                .foregroundStyle(member.isOwner ? Color.white : Color.shareInviteeText)
                .frame(width: 25, height: 25)
                .background(member.isOwner ? Color.neutral300 : Color.shareInviteeBackground, in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(member.isMe ? "\(member.name) (나)" : member.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.neutral900)
                Text(member.isOwner ? "프로젝트 소유자" : "초대된 멤버")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.neutral500)
            }
            Spacer()
            permission(of: member)
        }
        .padding(.leading, 9)
        .frame(height: 58)
    }

    // 소유자 / 읽기 가능 / 편집 가능. 총 연출자에게만 바꾸는 메뉴로 보인다
    // 수락 직후엔 그 사람 멤버 기록이 아직 안 왔을 수 있다 → 올 때까지 읽기 가능 글자만
    @ViewBuilder
    private func permission(of member: ShareMember) -> some View {
        let target = production.member(withUserID: member.userID)
        if member.isOwner {
            permissionText("소유자")
        } else if let target, !production.isSharedWithMe {
            permissionMenu(for: target)
        } else {
            permissionText(target?.canEdit == true ? "편집 가능" : "읽기 가능")
        }
    }

    private func permissionText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(Color.neutral500)
    }

    private func permissionMenu(for target: Member) -> some View {
        Menu {
            Picker("권한", selection: canEditBinding(for: target)) {
                Text("읽기 가능").tag(false)
                Text("편집 가능").tag(true)
            }
            .labelsHidden()
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 6) {
                Text(target.canEdit ? "편집 가능" : "읽기 가능")
                    .font(.system(size: 11.5, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(Color.noticeMetaText)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // 바꾸면 바로 저장 → CloudSync가 iCloud에 올려서 그 사람 맥에도 간다
    private func canEditBinding(for target: Member) -> Binding<Bool> {
        Binding {
            target.canEdit
        } set: { newValue in
            target.canEdit = newValue
            try? target.modelContext?.save()
        }
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

// 회색 바탕 + 진한 글자 (피그마 공유하기 버튼: 13 semibold neutral700)
private struct GrayButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.noticeMetaText : Color.neutral400)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                configuration.isPressed ? Color.neutral300 : Color.shareButtonBackground,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.shareButtonBorder, lineWidth: 1)
            }
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
    .popoverStyle(width: 420)
    .padding(40)
}
