//
//  CommentPopover.swift
//  CueFlow
//
//  B(셀리나) 담당 — 💬 주석 팝업
//  카드의 "💬 3" 버튼을 누르면 이 큐의 댓글·답글을 보고, 새 댓글이나 답글을 달 수 있다.
//  댓글 작성자는 store.currentMemberID (지금 앱을 쓰는 사람).
//

import SwiftUI

// MARK: - 카드에 들어가는 "💬 숫자" 버튼

struct CommentCountButton: View {
    @Environment(CueStore.self) private var store
    let cueID: Cue.ID

    @State private var isPresented = false

    var body: some View {
        let count = store.cue(cueID)?.comments.count ?? 0

        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "message")
                    .font(.system(size: 9))
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color(hex: 0x4A4A4A))
            .padding(.horizontal, 9)
            .frame(minWidth: 38, minHeight: 22)
            .background(Color(hex: 0xF2F2F2), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            CommentPopover(cueID: cueID) { isPresented = false }
        }
    }
}

// MARK: - 주석 팝업

struct CommentPopover: View {
    @Environment(CueStore.self) private var store
    let cueID: Cue.ID
    var onClose: () -> Void = {}

    @State private var draft = ""
    @State private var replyTarget: Comment?            // 답글을 다는 중인 댓글
    @State private var expandedIDs: Set<Comment.ID> = [] // 답글을 펼친 댓글
    @FocusState private var isInputFocused: Bool

    private var comments: [Comment] {
        (store.cue(cueID)?.comments ?? []).sorted { $0.createdAt < $1.createdAt }
    }
    private var threads: [Comment] { comments.filter { $0.parentID == nil } }
    private func replies(to id: Comment.ID) -> [Comment] { comments.filter { $0.parentID == id } }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.currentMemberID != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            commentList
            inputArea
        }
        .frame(width: 320)
        .background(Color.white.opacity(0.7))
    }

    // MARK: 댓글 목록

    @ViewBuilder
    private var commentList: some View {
        if threads.isEmpty {
            Text("아직 주석이 없어요.\n첫 주석을 남겨 보세요.")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: 0x9CA3AF))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 90)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(threads.enumerated()), id: \.element.id) { index, comment in
                            if index > 0 {
                                Rectangle()
                                    .fill(Color(hex: 0xB5B5B5))
                                    .frame(height: 1)
                                    .padding(.vertical, 12)
                            }
                            thread(comment)
                                .id(comment.id)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 22)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 360)
                .fixedSize(horizontal: false, vertical: true)
                .onAppear { proxy.scrollTo(threads.last?.id, anchor: .bottom) }
                .onChange(of: comments.count) {
                    withAnimation { proxy.scrollTo(threads.last?.id, anchor: .bottom) }
                }
            }
        }
    }

    // 댓글 하나 + 답글들
    private func thread(_ comment: Comment) -> some View {
        let replies = replies(to: comment.id)
        let isExpanded = expandedIDs.contains(comment.id)

        return VStack(alignment: .leading, spacing: 6) {
            CommentHeader(name: authorName(comment), date: comment.createdAt, nameSize: 18)
            Text(comment.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.black)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                if !replies.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            if isExpanded { expandedIDs.remove(comment.id) } else { expandedIDs.insert(comment.id) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("답글 \(replies.count)개")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                    }
                }
                Button("답글") { startReply(to: comment) }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .light))
            .foregroundStyle(Color(hex: 0x4F4F4F))

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(replies) { reply in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: 0x4F4F4F))
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 4) {
                                CommentHeader(name: authorName(reply), date: reply.createdAt, nameSize: 15)
                                Text(reply.text)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.black)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.leading, 4)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 입력창 + 취소 / 댓글

    private var inputArea: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if let replyTarget {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right")
                    Text("\(authorName(replyTarget))님에게 답글")
                    Spacer()
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(hex: 0x4F4F4F))
                .padding(.horizontal, 6)
            }

            TextField(replyTarget == nil ? "내용을 입력하세요." : "답글을 입력하세요.", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit(send)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(hex: 0xD9D9D9), in: .rect(cornerRadius: 17))

            HStack(spacing: 14) {
                Button("취소", action: cancel)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.black)

                Button(action: send) {
                    Text("댓글")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(canSend ? .white : Color(hex: 0x7A7A7A))
                        .frame(width: 56, height: 26)
                        .background(canSend ? Color(hex: 0x2E2E2E) : Color(hex: 0xF2F2F2), in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    // MARK: 동작

    private func startReply(to comment: Comment) {
        replyTarget = comment
        isInputFocused = true
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let me = store.currentMemberID else { return }
        store.addComment(cueID: cueID, authorID: me, text: text, parentID: replyTarget?.id)
        if let parent = replyTarget {
            expandedIDs.insert(parent.id)   // 방금 단 답글이 보이도록 펼치기
        }
        draft = ""
        replyTarget = nil
    }

    // 쓰던 내용이 있으면 지우고, 없으면 팝업 닫기
    private func cancel() {
        if draft.isEmpty && replyTarget == nil {
            onClose()
        } else {
            draft = ""
            replyTarget = nil
        }
    }

    private func authorName(_ comment: Comment) -> String {
        store.member(comment.authorID)?.name ?? "알 수 없음"
    }
}

// MARK: - 이름 + 날짜 "이지은 2026.10.01(금) 17:29"

private struct CommentHeader: View {
    let name: String
    let date: Date
    var nameSize: CGFloat = 18

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy.MM.dd(E) HH:mm"
        return f
    }()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name)
                .font(.system(size: nameSize, weight: .medium))
                .foregroundStyle(.black)
            Text(Self.formatter.string(from: date))
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(Color(hex: 0x4F4F4F))
        }
    }
}

// MARK: - 미리보기

#Preview("주석 팝업") {
    let store = CueStore.sample()
    let cue = store.cues.first { $0.action == "정원 전화 받으며 퇴장" } ?? store.cues[0]
    CommentPopover(cueID: cue.id)
        .environment(store)
}

#Preview("주석 없음") {
    let store = CueStore.sample()
    let cue = store.cues.first { $0.comments.isEmpty } ?? store.cues[0]
    CommentPopover(cueID: cue.id)
        .environment(store)
}
