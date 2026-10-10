//
//  Production.swift
//  CueFlow
//
//  공연 = 맨 위 상자. 씬과 파트를 모두 담는다.
//  나중에 팀원과 공유하는 단위가 된다.
//

import Foundation
import SwiftData

@Model
final class Production {
    var id: UUID = UUID()
    var title: String = ""              // 공연명 (예: "레미제라블")
    var genre: String = ""              // 공연 유형 (예: "뮤지컬")
    var firstShowDate: Date = Date()    // 첫 공연일
    var createdAt: Date = Date()
    var updatedAt: Date = Date()        // 마지막으로 수정한 날짜 (홈 목록 "수정한 날짜")
    var lastOpenedAt: Date = Date()     // 마지막으로 연 시간 (홈 "최근에 열어본 프로젝트")
    var isFavorite: Bool = false        // 즐겨찾기 여부

    // 공연을 지우면 그 안의 씬·파트(와 그 아래 전부)도 같이 지운다.
    @Relationship(deleteRule: .cascade, inverse: \ShowScene.production)
    var scenes: [ShowScene]? = []

    @Relationship(deleteRule: .cascade, inverse: \Part.production)
    var parts: [Part]? = []

    @Relationship(deleteRule: .cascade, inverse: \Member.production)
    var members: [Member]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \Notice.production)
    var notices: [Notice]? = []

    init(title: String, genre: String, firstShowDate: Date) {
        self.title = title
        self.genre = genre
        self.firstShowDate = firstShowDate
    }
}
