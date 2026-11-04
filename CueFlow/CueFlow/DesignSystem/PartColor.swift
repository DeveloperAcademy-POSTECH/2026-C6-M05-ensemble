//
//  PartColor.swift
//  CueFlow
//
//  파트 색 목록. 파트(행)마다 배경·강조·번호 색 한 세트를 쓴다.
//  Part.colorIndex 번째 세트를 쓰고, 목록보다 크면 처음부터 다시 돈다.
//  색 값은 Resource/Assets.xcassets 컬러셋에 있다.
//

import SwiftUI

struct PartColor {
    let background: Color   // 큐 카드 배경
    let accent: Color       // 파트 색상 막대, 강조
    let number: Color       // 큐 번호 글자
    let cell: Color         // 칸 왼쪽 막대 · 사이드바 카드 테두리
    let tint: Color         // 칸 바탕 (옅은 파트색)
    let check: Color        // 내가 확인한 큐의 확인 수 알약
    let listTag: Color      // 리허설 큐 목록의 위치 태그
    let sidebarChip: Color  // 미확인 사이드바의 번호 · 위치 태그
    let sidebarBorder: Color // 미확인 사이드바의 카드 테두리

    // 순서 = colorIndex 0, 1, 2 …
    static let all: [PartColor] = [
        PartColor(background: .stageBackground, accent: .stageAccent, number: .stageNumber, cell: .stageCell, tint: .stageTint, check: .stageCheck, listTag: .stageListTag, sidebarChip: .stageSidebarChip, sidebarBorder: .stageSidebarBorder),                  // 무대 (보라)
        PartColor(background: .propsBackground, accent: .propsAccent, number: .propsNumber, cell: .propsCell, tint: .propsTint, check: .propsCheck, listTag: .propsListTag, sidebarChip: .propsSidebarChip, sidebarBorder: .propsSidebarBorder),                  // 소품 (하늘)
        PartColor(background: .costumeBackground, accent: .costumeAccent, number: .costumeNumber, cell: .costumeCell, tint: .costumeTint, check: .costumeCheck, listTag: .costumeListTag, sidebarChip: .costumeSidebarChip, sidebarBorder: .costumeSidebarBorder),      // 의상 (남색)
        PartColor(background: .lightBackground, accent: .lightAccent, number: .lightNumber, cell: .lightCell, tint: .lightTint, check: .lightCheck, listTag: .lightListTag, sidebarChip: .lightSidebarChip, sidebarBorder: .lightSidebarBorder),                  // 조명 (파랑)
        PartColor(background: .soundBackground, accent: .soundAccent, number: .soundNumber, cell: .soundCell, tint: .soundTint, check: .soundCheck, listTag: .soundListTag, sidebarChip: .soundSidebarChip, sidebarBorder: .soundSidebarBorder),                  // 음향 (초록)
    ]

    static func at(_ index: Int) -> PartColor {
        let count = all.count
        return all[(index % count + count) % count]   // 음수가 들어와도 안전하게
    }
}

extension Part {
    // 사용법: part.color.accent
    var color: PartColor {
        PartColor.at(colorIndex)
    }
}
