//
//  Notice.swift
//  CueFlow
//
//  Created by yunseo on 10/10/26.
//

import Foundation
import SwiftData

@Model
final class Notice {
    var id: UUID = UUID()
    var title: String = ""              // 공지 제목
    var body: String = ""               // 내용
    var sentAt: Date = Date()              // 보낸 시간
    var isImportant: Bool = false               // 중요 여부 (팀 결정 전, 기본값 아님)

    var production: Production?                // 어느 공연의 공지인지
    var author: Member?                    // 누가 보냈는지

    // 읽음 기록들. 공지를 지우면 읽음 기록도 같이 지운다.
    @Relationship(deleteRule: .cascade, inverse: \NoticeRead.notice)
    var reads: [NoticeRead]? = []

    init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}
