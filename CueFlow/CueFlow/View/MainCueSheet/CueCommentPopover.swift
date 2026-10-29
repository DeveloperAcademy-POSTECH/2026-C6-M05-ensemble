//
//  CueCommentPopover.swift
//  CueFlow
//
//  Created by 김나현 on 10/30/26.
//
//  큐카드 💬 버튼 → 댓글 · 답글. "답글"을 누르면 그 댓글에 답글로 달림
//

import SwiftUI
import SwiftData

struct CueCommentPopover: View {
    let cue: Cue
    @Environment(\.myUserID) private var myUserID
    @Environment(\.modelContext) private var modelContext
    @Environment(\.closeAppPopover) private var closePopover
    @State private var text = ""
    @State private var replyTarget: Comment?   // nil = 새 댓글

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if topComments.isEmpty {
                authorHeader(name: myName, date: .now)
            } else {
                commentList
            }
            inputRow
                .padding(.top, 12)
            buttonRow
                .padding(.top, 12)
        }
    }
}

// 댓글 목록

extension CueCommentPopover {
    private var commentList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(topComments) { thread($0) }
        }
    }

    // 댓글 + 답글들 + 구분선
    private func thread(_ comment: Comment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            commentView(comment, isReply: false)
            ForEach((comment.replies ?? []).sorted { $0.createdAt < $1.createdAt }) { reply in
                commentView(reply, isReply: true)
                    .padding(.leading, 28)
            }
            Color.neutral200
                .frame(height: 1)
        }
    }

    private func commentView(_ comment: Comment, isReply: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                authorHeader(name: comment.author?.name ?? "이름 없음", date: comment.createdAt)
                Spacer(minLength: 0)
                if !isReply { replyCount(comment) }
            }
            Text(comment.text)
                .font(.system(size: 12))
                .lineSpacing(2)
                .foregroundStyle(Color.neutral900)
                .fixedSize(horizontal: false, vertical: true)
            if !isReply { replyButton(comment) }
        }
    }

    private func authorHeader(name: String, date: Date) -> some View {
        HStack(spacing: 8) {
            avatar(name)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.neutral900)
                Text(date.commentText)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.neutral600)
            }
        }
    }

    private func avatar(_ name: String) -> some View {
        MemberAvatar(name: name, size: 26, background: .neutral200, letterColor: .neutral500, fontSize: 11)
    }

    @ViewBuilder
    private func replyCount(_ comment: Comment) -> some View {
        let count = comment.replies?.count ?? 0
        if count > 0 {
            Text("답글 \(count)개")
                .font(.system(size: 10))
                .foregroundStyle(Color.neutral600)
        }
    }

    private func replyButton(_ comment: Comment) -> some View {
        Button("답글") { replyTarget = comment }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(replyTarget == comment ? Color.brandPrimaryText : Color.neutral900)
    }
}

// 입력칸 · 버튼

extension CueCommentPopover {
    private var inputRow: some View {
        HStack(spacing: 8) {
            if !topComments.isEmpty { avatar(myName) }
            TextField("", text: $text, prompt: .popoverPlaceholder, axis: .vertical)
                .onSubmit(post)
                .popoverInputStyle()
        }
    }

    private var buttonRow: some View {
        HStack(spacing: 10) {
            Spacer()
            smallButton("취소", isFilled: false, action: cancel)
            smallButton("댓글", isFilled: true, action: post)
        }
    }

    private func smallButton(_ title: String, isFilled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.neutral700)
                .frame(width: 56, height: 26)
                .background(isFilled ? Color.neutral200 : Color.neutral25, in: .rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isFilled ? .clear : Color.neutral300))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// 데이터

extension CueCommentPopover {
    // 오래된 것 위 → 최근 것 아래
    private var topComments: [Comment] {
        (cue.comments ?? []).filter { $0.parent == nil }.sorted { $0.createdAt < $1.createdAt }
    }

    private var myName: String {
        cue.part?.production?.member(withUserID: myUserID)?.name ?? CurrentEditor.name
    }

    // 답글 중이면 답글만 취소, 아니면 닫기
    private func cancel() {
        if replyTarget == nil { closePopover() } else { replyTarget = nil }
    }

    private func post() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let comment = Comment(text: trimmed)
        comment.createdAt = .now   // 순서가 섞이지 않게 직접 넣음
        modelContext.insert(comment)
        comment.cue = cue
        comment.parent = replyTarget
        if let myUserID, let production = cue.part?.production {
            comment.author = modelContext.me(in: production, userID: myUserID)
        }
        text = ""
        replyTarget = nil
    }
}
