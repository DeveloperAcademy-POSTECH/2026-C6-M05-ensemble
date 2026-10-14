//
//  StagePlacement.swift
//  CueFlow
//
//  무대 배치 = 배역 · 소품 하나가 무대 미니맵 어디에 있는지.
//  공연에 붙으면 "최초 상태 무대 배치", 장면에 붙으면 그 장면의 배치.
//  장면에 배치가 없으면 최초 상태 배치를 보여준다.
//

import Foundation
import SwiftData

// 미니맵의 세 구역
enum StageArea: String, Codable, CaseIterable {
    case sangsu = "상수"
    case stage = "무대"
    case hasu = "하수"
}

// 배역(동그라미)인지 소품(세모)인지
enum StageItemKind: String, Codable {
    case cast = "배역"
    case prop = "소품"
}

@Model
final class StagePlacement {
    var id: UUID = UUID()
    var name: String = ""                       // 배역 · 소품 이름 (Production.castNames / propNames)
    var kind: StageItemKind = StageItemKind.cast
    var area: StageArea = StageArea.stage
    var x: Double = 0.5                         // 구역 안 가로 위치 (0 = 왼쪽 끝, 1 = 오른쪽 끝)
    var y: Double = 0.5                         // 구역 안 세로 위치 (0 = 위, 1 = 아래)

    var production: Production?                 // 최초 상태 배치일 때
    var scene: ShowScene?                       // 이 장면의 배치일 때

    init(name: String, kind: StageItemKind, area: StageArea, x: Double, y: Double) {
        self.name = name
        self.kind = kind
        self.area = area
        self.x = x
        self.y = y
    }
}
