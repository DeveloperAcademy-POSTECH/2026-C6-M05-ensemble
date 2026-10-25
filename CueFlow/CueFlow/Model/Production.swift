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
    var lastShowDate: Date?             // 마지막 공연일 (하루 공연이면 nil)
    var venue: String = ""              // 공연장 (예: "아트스페이스 대극장")
    var seatCount: Int?                 // 객석 규모 (예: 1200)
    var organizer: String = ""          // 주최
    var runningTime: Int?               // 러닝타임 (분)
    var createdAt: Date = Date()
    var updatedAt: Date = Date()        // 마지막으로 수정한 날짜 (홈 목록 "수정한 날짜")
    var lastOpenedAt: Date = Date()     // 마지막으로 연 시간 (홈 "최근에 열어본 프로젝트")
    var isFavorite: Bool = false        // 즐겨찾기 여부

    // 공유받은 공연이면 주인의 iCloud 계정 이름 (iCloud 폴더가 주인 쪽에 있음). 내가 만든 공연이면 nil
    // 이 맥에서만 쓰는 값이라 iCloud에 올리지 않는다 (#68)
    var cloudZoneOwnerName: String?

    // 대본 입력 · 배우 · 소품 목록에서 정한 배역 · 소품 이름. 리허설 무대 미니맵에 놓는다
    var castNames: [String] = []
    var propNames: [String] = []

    // 공연을 지우면 그 안의 씬·파트(와 그 아래 전부)도 같이 지운다.
    @Relationship(deleteRule: .cascade, inverse: \ShowScene.production)
    var scenes: [ShowScene]? = []

    @Relationship(deleteRule: .cascade, inverse: \Part.production)
    var parts: [Part]? = []

    @Relationship(deleteRule: .cascade, inverse: \Member.production)
    var members: [Member]? = []

    // 최초 상태 무대 배치. 아직 배치하지 않은 장면은 이걸 보여준다
    @Relationship(deleteRule: .cascade, inverse: \StagePlacement.production)
    var initialPlacements: [StagePlacement]? = []

    init(title: String, genre: String, firstShowDate: Date) {
        self.title = title
        self.genre = genre
        self.firstShowDate = firstShowDate
    }
}
