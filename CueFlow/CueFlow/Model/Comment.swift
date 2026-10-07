//
//  Comment.swift
//  CueFlow
//
//  댓글 = 큐에 다는 글. 답글은 원래 댓글(parent) 아래에 달린다.
//

import Foundation
import SwiftData

// 댓글 태그. 피그마 "주석 달기"의 Tag 선택.
enum CommentKind: String, Codable, CaseIterable {
    case suggestion = "제안"
    case question = "질문"
}

@Model
final class Comment {
    var id: UUID = UUID()
    var text: String = ""
    var kind: CommentKind?              // 태그 (없을 수도 있음, 답글은 보통 없음)
    var createdAt: Date = Date()

    var cue: Cue?                       // 어느 큐의 댓글인지
    var author: Member?                 // 누가 썼는지

    var parent: Comment?                // 답글이면 원래 댓글, 아니면 nil

    // 이 댓글에 달린 답글들. 댓글을 지우면 답글도 같이 지운다.
    @Relationship(deleteRule: .cascade, inverse: \Comment.parent)
    var replies: [Comment]? = []

    init(text: String, kind: CommentKind? = nil) {
        self.text = text
        self.kind = kind
    }
}
