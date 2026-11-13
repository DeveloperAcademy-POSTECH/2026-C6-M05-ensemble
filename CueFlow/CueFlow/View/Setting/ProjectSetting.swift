//
//  ProjectSetting.swift
//  CueFlow
//
//  Created by 김나현 on 11/12/26.
//
//  홈 목록 우클릭 → "프로젝트 설정". 단축키 창처럼 화면 가운데 카드로 뜬다.
//  공연 정보 보기 · 수정 + 나가기 / 삭제하기
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
    
    // 공연을 만든 사람이면 삭제하기, 초대받은 사람이면 나가기
    private var isCreator: Bool { !production.isSharedWithMe }
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

            exitButton
                .padding(.top, 60)
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
            .frame(width: 105, height: 35)   // 피그마 크기 고정 (아이콘이 바뀌어도 그대로)
            .background(isEditing ? Color.brandPrimarySubtle : Color.neutral200, in: .rect(cornerRadius: 6))   // 수정하기 회색 → 저장하기 보라
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
