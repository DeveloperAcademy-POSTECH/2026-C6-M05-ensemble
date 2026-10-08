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

    // 순서 = colorIndex 0, 1, 2 …
    static let all: [PartColor] = [
        PartColor(background: .stageBackground, accent: .stageAccent, number: .stagenumber),          // 무대 (보라)
        PartColor(background: .propsbackground, accent: .propsaccent, number: .propsnumber),          // 소품 (하늘)
        PartColor(background: .costumebackground, accent: .costumeaccent, number: .costumenumber),    // 의상 (남색)
        PartColor(background: .lightbackground, accent: .lightaccent, number: .lightnumber),          // 조명 (파랑)
        PartColor(background: .soundbackground, accent: .soundaccent, number: .soundnumber),          // 음향 (초록)
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
