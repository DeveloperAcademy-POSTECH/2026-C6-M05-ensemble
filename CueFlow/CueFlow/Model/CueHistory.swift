//
//  CueHistory.swift
//  CueFlow
//
//  Created by 김나현 on 10/29/26.
//

import Foundation
import SwiftData

@Model
final class CueHistory {
    var id: UUID = UUID()
    var title: String = ""         // "트리거 변경", "위치 변경", "큐 생성" …
    var detail: String = ""        // "김나현님의 수정", "김나현님이 하수 → 상수로 변경"
    var before: String?            // 이전 값 (있으면 이전 · 변경 상자)
    var after: String?             // 바뀐 값
    var isChange: Bool = true      // 변경이면 진한 점, 생성 · 추가면 연한 점
    var date: Date = Date()        // 언제
    var cue: Cue?                  // 어느 큐의 기록인지

    init(title: String, detail: String, before: String? = nil, after: String? = nil, isChange: Bool = true) {
        self.title = title
        self.detail = detail
        self.before = before
        self.after = after
        self.isChange = isChange
    }
}

// 지금 수정하는 사람 이름. 아직 팀원 연결(#68)이 없어서 이 맥의 사용자 이름을 쓴다
enum CurrentEditor {
    static var name: String { NSFullUserName() }
}

extension Cue {
    // 이 큐에 기록 한 줄 남기기
    func addHistory(_ title: String, detail: String, before: String? = nil, after: String? = nil, isChange: Bool = true) {
        let history = CueHistory(title: title, detail: detail, before: before, after: after, isChange: isChange)
        modelContext?.insert(history)
        history.cue = self
    }
}
