//
//  NoticeComposeView.swift
//  CueFlow
//
//  공지 쓰기 화면 (피그마 951:7451 공지사항_02).
//  보내기를 누르면 공지를 저장하고 목록으로 돌아간다.
//

import SwiftUI
import SwiftData

struct NoticeComposeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // 프로젝트 선택 목록에 보여줄 공연들
    @Query(sort: \Production.updatedAt, order: .reverse)
    private var productions: [Production]

    @State private var selectedProduction: Production?
    @State private var recipient: NoticeRecipient = .all
    @State private var title = ""
    @State private var content = ""

    // 프로젝트를 고르고 제목·내용을 다 써야 보낼 수 있다
    private var canSend: Bool {
        selectedProduction != nil
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("공지사항")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.neutral900)
                    .padding(.bottom, 10)   // 제목 → 칸 30

                field("프로젝트") {
                    projectMenu
                        // 프로젝트를 바꾸면 이전 프로젝트의 파트·사람은 고를 수 없으니 전체로 되돌린다
                        .onChange(of: selectedProduction) {
                            recipient = .all
                        }
                }

                // 이름·파트 검색해서 고르기. 비워 두면 전체
                field("보낼 대상") {
                    NoticeRecipientField(production: selectedProduction, recipient: $recipient)
                }

                field("공지 제목") {
                    TextField("", text: $title, prompt: placeholder("공지 제목을 입력하세요."))
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundStyle(Color.neutral900)
                        .padding(.horizontal, 25)
                        .frame(height: 50)
                        .background(.white, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(fieldBorder)
                }

                field("내용", labelTop: 0) {
                    TextEditor(text: $content)
                        .font(.body)
                        .foregroundStyle(Color.neutral900)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 20)   // TextEditor 안쪽 여백(5)까지 더해서 피그마 25
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                        .frame(height: 260)
                        .background(.white, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(alignment: .topLeading) {
                            // TextEditor에는 안내 글자가 없어서 비어 있을 때만 직접 보여준다
                            if content.isEmpty {
                                placeholder("공지 내용을 입력하세요.")
                                    .padding(.leading, 25)
                                    .padding(.top, 20)
                                    .allowsHitTesting(false)
                            }
                        }
                        .overlay(fieldBorder)
                }

                // 오른쪽 아래 보내기 버튼 (피그마: 보라 바탕 · 13 레귤러 · 110×30)
                HStack {
                    Spacer()
                    Button(action: send) {
                        Text("보내기")
                            .font(.body)
                            .foregroundStyle(Color.neutral25)
                            .frame(width: 110, height: 30)
                            .background(Color.brandPrimary, in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .opacity(canSend ? 1 : 0.4)
                }
            }
            .frame(maxWidth: 1069, alignment: .leading)
            .padding(40)
        }
        .background(.white)
        // 피그마: 시스템 뒤로 버튼 대신 왼쪽 위 ← (24 · neutral700)
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.neutral700)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("공지 목록으로")
            .padding(.leading, 26)
            .padding(.top, 34)
        }
    }

    // "프로젝트 선택 ⌄" (피그마 951:7460: 흰 바탕 · 회색 테두리 · 높이 50)
    private var projectMenu: some View {
        Menu {
            Button("프로젝트 선택") { selectedProduction = nil }
            Divider()
            ForEach(productions) { production in
                Button(production.title) { selectedProduction = production }
            }
        } label: {
            HStack(spacing: 11) {
                Text(selectedProduction?.title ?? "프로젝트 선택")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(selectedProduction == nil ? Color.neutral400 : Color.neutral900)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.neutral600)
            }
            .padding(.horizontal, 19)
            .frame(minWidth: 144, minHeight: 50, maxHeight: 50)
            .background(.white, in: RoundedRectangle(cornerRadius: 6))
            .overlay(fieldBorder)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // 칸 안내 글자 (피그마: 13 semibold neutral400)
    private func placeholder(_ text: String) -> Text {
        Text(text)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.neutral400)
    }

    // 왼쪽 이름표 + 오른쪽 입력 칸 한 줄 (피그마: 15 semibold neutral800 · 칸은 왼쪽에서 91)
    // labelTop: 높이 50 칸 가운데에 오게 15, 내용 칸은 위에 붙여서 0
    private func field<Content: View>(_ label: String, labelTop: CGFloat = 15, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.neutral800)
                .frame(width: 91, alignment: .leading)
                .padding(.top, labelTop)
            content()
        }
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(Color.neutral300, lineWidth: 1)
    }

    // 공지를 만들어 저장하고 목록으로 돌아간다
    private func send() {
        let notice = Notice(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: content.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(notice)
        notice.production = selectedProduction
        switch recipient {
        case .all: break                              // 둘 다 비워 두면 전체
        case .part(let part): notice.targetPart = part
        case .member(let member): notice.targetMember = member
        }
        // 보낸 사람 = 이 공연의 "나" 멤버 (없으면 만든다 · CueMembers). iCloud 로그인 안 됐으면 "알 수 없음"
        if let myID = ICloudAccount.currentUserRecordName, let production = selectedProduction {
            notice.author = modelContext.me(in: production, userID: myID)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        NoticeComposeView()
    }
    .modelContainer(HomePreviewData.container)
    .frame(width: 1290, height: 930)
}
