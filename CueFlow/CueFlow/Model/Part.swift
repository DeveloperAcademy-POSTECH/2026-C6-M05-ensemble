//
//  Part.swift
//  CueFlow
//
//  파트 = 메인 화면의 행 (무대, 소품, 의상, 조명, 음향 …).
//

import Foundation
import SwiftData

@Model
final class Part {
    var id: UUID = UUID()
    var name: String = ""           // 예: "조명"
    var order: Int = 0              // 화면에서 위에서부터 몇 번째 행인지
    var colorIndex: Int = 0         // 정해진 색 목록에서 몇 번째 색인지 (넘치면 처음부터 다시)

    var production: Production?     // 어느 공연의 파트인지

    // 이 파트에 속한 큐들. 파트를 지우면 그 파트의 큐도 같이 지운다.
    @Relationship(deleteRule: .cascade, inverse: \Cue.part)
    var cues: [Cue]? = []

    var members: [Member]? = []     // 이 파트를 맡은 멤버들 (Member.parts의 짝)

    // 이 파트에게 보낸 공지들. 파트를 지워도 공지는 남긴다 (대상만 비어짐).
    @Relationship(deleteRule: .nullify, inverse: \Notice.targetPart)
    var targetedNotices: [Notice]? = []

    init(name: String, order: Int, colorIndex: Int) {
        self.name = name
        self.order = order
        self.colorIndex = colorIndex
    }
}
