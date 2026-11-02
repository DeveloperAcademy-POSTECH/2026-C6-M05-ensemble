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
    // 별표(중요) · 내 목록에서 숨김. "나한테만" 의미 있는 값이라 iCloud에 올리지 않고 이 맥에만 저장
    var isImportant: Bool = false
    var isHiddenByMe: Bool = false      // 남이 보낸 공지를 삭제하면 지우지 않고 내 목록에서만 숨긴다

    var production: Production?                // 어느 공연의 공지인지
    var author: Member?                    // 누가 보냈는지

    // 보낼 대상. 둘 다 비어 있으면 프로젝트 전체 멤버, 하나만 채워진다.
    var targetPart: Part?                       // 특정 파트에게 (예: 조명)
    var targetMember: Member?                   // 특정 사람에게

    // 읽음 기록들. 공지를 지우면 읽음 기록도 같이 지운다.
    @Relationship(deleteRule: .cascade, inverse: \NoticeRead.notice)
    var reads: [NoticeRead]? = []

    init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}
