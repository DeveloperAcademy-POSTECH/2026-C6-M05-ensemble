//
//  ProjectSetting.swift
//  CueFlow
//
//  Created by 김나현 on 11/12/26.
//
//  홈 목록 우클릭 → "프로젝트 설정". 단축키 창처럼 화면 가운데 카드로 뜬다.
//  공연 정보 보기 · 수정 + 스태프 관리(역할 · 권한) + 나가기 / 삭제하기
//

import SwiftData
import SwiftUI

struct ProjectSetting: View {
    let production: Production
    var onClose: () -> Void = {}
    var onDelete: () -> Void = {}   // 만든 사람: 홈의 삭제 확인 창을 띄운다
    var onLeave: () -> Void = {}    // 초대받은 사람: 나가기 확인 후 부름

    @Environment(ICloudAccount.self) private var iCloudAccount
    @AppStorage("profileEmail") private var myEmail = ""   // 앱 설정에서 입력한 내 이메일

    @State private var isEditing = false
    @State private var draft = ProductionDraft()
    @State private var isConfirmingLeave = false

    private static let roles = ["감독", "스태프"]

    // 공연을 만든 사람만 역할 · 권한을 바꿀 수 있다
    private var isCreator: Bool { !production.isSharedWithMe }

    private var members: [Member] {
        (production.members ?? []).sorted { $0.name < $1.name }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onClose() }   // 카드 바깥을 누르면 닫힘

            card
        }
        .onAppear { draft = ProductionDraft(production) }
        .alert("\(production.title)에서 나갈까요?", isPresented: $isConfirmingLeave) {
            Button("취소", role: .cancel) {}
            Button("나가기", role: .destructive) { onLeave() }
        } message: {
            Text("나가면 목록에서 사라지고, 다시 초대받아야 볼 수 있어요.")
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("프로젝트 설정")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.neutral900)

            ScrollView {
                content
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 61)
        .padding(.horizontal, 62)
        .frame(width: 924, height: 636)
        .background(Color.surfaceWhite, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.neutral200))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        .appPopoverHost()   // 공연일 달력 팝오버가 그려지는 곳
        .background { closeShortcut }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if production.canEdit(userID: iCloudAccount.userRecordName) {
                editButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 34)
            }

            ProductionForm(draft: $draft)
                .allowsHitTesting(isEditing)   // 보기 상태에선 값만 보이고 안 눌림

            staffSection
                .padding(.top, 60)

            exitButton
                .padding(.top, 28)
        }
        .padding(.bottom, 61)
    }

    // Esc로 닫기 (보이지 않는 버튼)
    private var closeShortcut: some View {
        Button("닫기", action: onClose)
            .keyboardShortcut(.cancelAction)
            .opacity(0)
    }
}

// 수정하기 ↔ 저장하기

extension ProjectSetting {
    private var editButton: some View {
        Button {
            if isEditing { saveInfo() } else { isEditing = true }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: isEditing ? "square.and.arrow.down" : "pencil.line")
                    .font(.system(size: 18))
                Text(isEditing ? "저장하기" : "수정하기")
                    .font(.system(size: 16))
            }
            .foregroundStyle(Color.neutral900)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Color.brandPrimarySubtle, in: .rect(cornerRadius: 6))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // 고친 값을 공연에 넣고 저장 → CloudSync가 함께 쓰는 사람에게도 보낸다
    private func saveInfo() {
        guard !draft.title.trimmingCharacters(in: .whitespaces).isEmpty else { return }   // 공연명은 필수
        production.title = draft.title
        production.genre = draft.genre
        production.firstShowDate = draft.firstShowDate
        production.lastShowDate = draft.lastShowDate
        production.venue = draft.venue
        production.seatCount = draft.seatCount
        production.organizer = draft.organizer
        production.runningTime = draft.runningTime
        production.updatedAt = .now
        save()
        isEditing = false
    }

    private func save() {
        try? production.modelContext?.save()
    }
}

// 스태프 관리 표

extension ProjectSetting {
    private var staffSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("스태프 관리")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.neutral800)
            staffTable
        }
    }

    private var staffTable: some View {
        VStack(spacing: 0) {
            tableHeader
            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                Color.neutral300.frame(height: 1)   // 줄 사이 구분선 (마지막 줄 아래는 없음)
                staffRow(member, index: index)
            }
        }
        .frame(width: 800)
        .background(Color.surfaceWhite, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.neutral300))
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 58)
            Text("이름").column(114, leading: 12.5)
            Text("계정").column(298, leading: 25.5)
            Text("역할").column(164, leading: 17)
            Text("권한").column(170, leading: 17)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color.neutral900)
        .frame(height: 44)
    }

    private func staffRow(_ member: Member, index: Int) -> some View {
        HStack(spacing: 0) {
            avatar(member, index: index)
                .frame(width: 58)
            Text(member.name).column(114, leading: 12.5)
            Text(accountText(member)).column(298, leading: 25.5)
            roleCell(member).column(164, leading: 17)
            permissionCell(member).column(170, leading: 17)
        }
        .font(.system(size: 13))
        .foregroundStyle(Color.neutral900)
        .frame(height: 51)
    }

    // 이름 첫 글자 동그라미 (줄마다 색을 번갈아)
    private func avatar(_ member: Member, index: Int) -> some View {
        Text(String(member.name.prefix(1)))
            .font(.system(size: 13))
            .foregroundStyle(Color.brandPrimaryText)
            .frame(width: 31, height: 31)
            .background(index.isMultiple(of: 2) ? Color.brandPrimarySubtle : Color.brandPrimaryDisabled, in: Circle())
    }

    // 다른 사람 이메일은 아직 받을 방법이 없어서 내 줄만 (앱 설정에서 입력한 값)
    private func accountText(_ member: Member) -> String {
        guard isMe(member), !myEmail.isEmpty else { return "-" }
        return myEmail
    }

    private func isMe(_ member: Member) -> Bool {
        guard let myID = iCloudAccount.userRecordName else { return false }
        return member.iCloudUserID == myID
    }
}

// 역할 · 권한 드롭다운 (만든 사람만 바꿀 수 있고, 나머지는 값만 보임)

extension ProjectSetting {
    private func roleCell(_ member: Member) -> some View {
        dropdown(member.role.isEmpty ? "스태프" : member.role, isEnabled: isCreator) {
            ForEach(Self.roles, id: \.self) { role in
                Button(role) {
                    member.role = role
                    save()
                }
            }
        }
    }

    // 만든 사람 자기 줄은 항상 편집가능 (바꿀 수 없음)
    private func permissionCell(_ member: Member) -> some View {
        let isCreatorRow = isCreator && isMe(member)
        let title = isCreatorRow || member.canEdit ? "편집가능" : "읽기 전용"
        return dropdown(title, isEnabled: isCreator && !isCreatorRow) {
            Button("편집가능") { setCanEdit(member, true) }
            Button("읽기 전용") { setCanEdit(member, false) }
        }
    }

    private func setCanEdit(_ member: Member, _ canEdit: Bool) {
        member.canEdit = canEdit
        save()
    }

    @ViewBuilder
    private func dropdown<Items: View>(_ title: String, isEnabled: Bool,
                                       @ViewBuilder items: () -> Items) -> some View {
        if isEnabled {
            Menu { items() } label: { dropdownLabel(title, showsChevron: true) }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
        } else {
            dropdownLabel(title, showsChevron: false)
        }
    }

    private func dropdownLabel(_ title: String, showsChevron: Bool) -> some View {
        HStack(spacing: 0) {
            Text(title)
            Spacer(minLength: 4)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Color.neutral900)
        .padding(.horizontal, 12)
        .frame(width: 89, height: 31)
        .background(Color.neutral100, in: .rect(cornerRadius: 16))
        .contentShape(.rect)
    }
}

// 프로젝트 나가기 / 삭제하기

extension ProjectSetting {
    @ViewBuilder
    private var exitButton: some View {
        if isCreator {
            dangerButton("프로젝트 삭제하기", action: onDelete)
        } else {
            dangerButton("프로젝트 나가기") { isConfirmingLeave = true }
        }
    }

    private func dangerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Color.error)
                .frame(width: 150, height: 36)
                .background(Color.errorSubtle, in: .rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.error))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// 공연에 저장된 값으로 입력칸 채우기
extension ProductionDraft {
    init(_ production: Production) {
        self.init(title: production.title, genre: production.genre,
                  firstShowDate: production.firstShowDate, lastShowDate: production.lastShowDate,
                  venue: production.venue, seatCount: production.seatCount,
                  organizer: production.organizer, runningTime: production.runningTime)
    }
}

// 표 칸: 왼쪽 여백 + 고정 폭
private extension View {
    func column(_ width: CGFloat, leading: CGFloat) -> some View {
        padding(.leading, leading)
            .frame(width: width, alignment: .leading)
    }
}

#Preview {
    let container = try! ModelContainer(for: Production.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let production = Production(title: "레미제라블", genre: "뮤지컬", firstShowDate: .now)
    container.mainContext.insert(production)
    for (name, role) in [("이진환", "감독"), ("곽선우", "스태프"), ("코우", "스태프")] {
        let member = Member(name: name, role: role)
        container.mainContext.insert(member)
        member.production = production
    }
    return ProjectSetting(production: production)
        .frame(width: 1290, height: 930)
        .environment(ICloudAccount())
        .modelContainer(container)
}
