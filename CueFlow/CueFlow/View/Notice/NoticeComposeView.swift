//
//  NoticeComposeView.swift
//  CueFlow
//
//  공지 쓰기 화면 (피그마 공지사항_02).
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
            VStack(alignment: .leading, spacing: 24) {
                Text("공지사항")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 16)

                field("프로젝트") {
                    Picker("", selection: $selectedProduction) {
                        Text("프로젝트 선택").tag(Production?.none)
                        ForEach(productions) { production in
                            Text(production.title).tag(Optional(production))
                        }
                    }
                    .labelsHidden()
                }

                // 지금은 항상 프로젝트 전체 멤버에게 보낸다
                field("보낼 대상") {
                    Text("프로젝트 전체 멤버 (\(selectedProduction?.members?.count ?? 0)명)")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 49, alignment: .leading)
                        .padding(.horizontal, 16)
                        .overlay(fieldBorder)
                }

                field("공지 제목") {
                    TextField("공지 제목을 입력하세요.", text: $title)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .frame(height: 49)
                        .overlay(fieldBorder)
                }

                field("내용") {
                    TextEditor(text: $content)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .frame(height: 257)
                        .overlay(alignment: .topLeading) {
                            // TextEditor에는 안내 글자가 없어서 비어 있을 때만 직접 보여준다
                            if content.isEmpty {
                                Text("공지 내용을 입력하세요.")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 17)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                        }
                        .overlay(fieldBorder)
                }

                // 오른쪽 아래 보내기 버튼
                HStack {
                    Spacer()
                    Button("보내기") {
                        send()
                    }
                    .buttonStyle(.primary)
                    .frame(width: 125, height: 40)
                    .disabled(!canSend)
                    .opacity(canSend ? 1 : 0.4)
                }
            }
            .frame(maxWidth: 1070, alignment: .leading)
            .padding(40)
        }
    }

    // 왼쪽 이름표 + 오른쪽 입력 칸 한 줄
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.body.weight(.semibold))
                .frame(width: 90, alignment: .leading)
                .padding(.top, 14)
            content()
        }
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
    }

    // 공지를 만들어 저장하고 목록으로 돌아간다
    private func send() {
        let notice = Notice(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: content.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(notice)
        notice.production = selectedProduction
        // TODO: "나"를 알게 되면 notice.author = 나 (지금은 "알 수 없음"으로 보임)
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
