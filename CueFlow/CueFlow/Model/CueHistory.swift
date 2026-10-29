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

// 지금 수정하는 사람 이름. 이 공연 멤버 중 내 iCloud 계정이면 멤버 이름(공유한 사람들끼리 같은 이름),
// 멤버가 아니면(공유 전 · 혼자 쓰는 공연) 이 맥의 사용자 이름 (#86)
enum CurrentEditor {
    // 공연을 모를 때 (예전 코드 · 셀리나 #96 댓글 등에서 씀) — 이 맥의 사용자 이름
    static var name: String { NSFullUserName() }

    static func name(in production: Production?) -> String {
        let myID = ICloudAccount.currentUserRecordName
        let member = (production?.members ?? []).first { myID != nil && $0.iCloudUserID == myID }
        if let name = member?.name, !name.isEmpty { return name }
        return NSFullUserName()
    }
}

extension Cue {
    // 이 큐를 고치는 사람 이름 (기록 문구에 쓴다)
    var editorName: String { CurrentEditor.name(in: cloudProduction) }

    // 이 큐에 기록 한 줄 남기기
    func addHistory(_ title: String, detail: String, before: String? = nil, after: String? = nil, isChange: Bool = true) {
        let history = CueHistory(title: title, detail: detail, before: before, after: after, isChange: isChange)
        modelContext?.insert(history)
        history.cue = self
    }
}
