//
//  Cue.swift
//  CueFlow
//
//  큐 = 스태프가 해야 할 일 하나 (예: "자베르 고지대 등장").
//  큐는 트리거에 붙고, 같은 트리거에 붙은 큐는 동시에 실행한다.
//

import Foundation
import SwiftData

// 큐가 일어나는 위치. 나중에 위치가 늘어나면 case만 추가하면 된다.
enum CuePosition: String, Codable, CaseIterable {
    case sangsu = "상수"
    case hasu = "하수"
    case stage = "무대"
}

@Model
final class Cue {
    var id: UUID = UUID()
    var title: String = ""                  // 카드 첫 줄 (예: "자베르 고지대 등장")
    var position: CuePosition = CuePosition.stage
    var order: Int = 0                      // 같은 칸(파트 × 트리거) 안에서의 순서 → 카드의 01, 02
    var createdAt: Date = Date()

    var part: Part?                         // 어느 파트의 큐인지 (예: 조명)
    var trigger: Trigger?                   // 언제 실행하는지 (카드 둘째 줄)

    // 큐를 지우면 댓글·확인 기록도 같이 지운다.
    @Relationship(deleteRule: .cascade, inverse: \Comment.cue)
    var comments: [Comment]? = []

    @Relationship(deleteRule: .cascade, inverse: \CueCheck.cue)
    var checks: [CueCheck]? = []

    init(title: String, position: CuePosition, order: Int) {
        self.title = title
        self.position = position
        self.order = order
    }
}
