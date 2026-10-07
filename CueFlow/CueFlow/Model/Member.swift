//
//  Member.swift
//  CueFlow
//
//  멤버 = 공연에 참여하는 사람. 댓글·확인의 "누가"에 쓰인다.
//  한 사람이 파트를 여러 개 맡을 수 있고, 파트가 없을 수도 있다 (예: 감독 — 아직 미정).
//

import Foundation
import SwiftData

@Model
final class Member {
    var id: UUID = UUID()
    var name: String = ""               // 예: "이진환"
    var role: String = ""               // 맡은 일 (예: "무대연출", "감독")
    var iCloudUserID: String?           // 팀원 공유 단계에서 iCloud 계정과 연결할 자리

    var production: Production?         // 어느 공연의 멤버인지

    // 맡은 파트들 (여러 개 가능, 없어도 됨). 파트를 지워도 멤버는 남는다.
    @Relationship(deleteRule: .nullify, inverse: \Part.members)
    var parts: [Part]? = []

    // 멤버가 나가도 댓글은 남긴다 (작성자만 비어짐).
    @Relationship(deleteRule: .nullify, inverse: \Comment.author)
    var comments: [Comment]? = []

    // 멤버가 나가면 그 사람의 확인 기록은 지운다 (확인 숫자에서 빠지도록).
    @Relationship(deleteRule: .cascade, inverse: \CueCheck.member)
    var checks: [CueCheck]? = []

    init(name: String, role: String) {
        self.name = name
        self.role = role
    }
}
