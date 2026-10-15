//
//  PartOption.swift
//  CueFlow
//
//  Created by 김나현 on 10/16/26.
//

import Foundation
import SwiftData

// 새 공연 만들기에서 고를 수 있는 파트 (이름 + 아이콘)
struct PartOption: Hashable {
    let name: String
    let icon: String   // SF Symbol 이름
    
    // 기타 · 직접 추가한 파트가 같이 쓰는 아이콘
    static let customIcon = "circle.grid.2x2"

    // 피그마 카드 순서 그대로
    static let all = [
        PartOption(name: "무대", icon: "rectangle.badge.sparkles"),
        PartOption(name: "소품", icon: "gift"),
        PartOption(name: "의상", icon: "tshirt"),
        PartOption(name: "조명", icon: "lightbulb"),
        PartOption(name: "음향", icon: "speaker.wave.2"),
        PartOption(name: "영상", icon: "video"),
        PartOption(name: "특수효과", icon: "bubbles.and.sparkles"),
        PartOption(name: "분장", icon: "theatermask.and.paintbrush"),
        PartOption(name: "기타", icon: customIcon),
    ]
}

extension Part {
    // 고른 파트 이름들로 Part 만들기. 순서·색 번호는 기본 목록 → 직접 추가한 순서를 따른다.
    static func makeParts(named names: Set<String>, customNames: [String] = []) -> [Part] {
        let allNames = PartOption.all.map(\.name) + customNames   // 기본 목록 뒤에 직접 추가한 파트
        return allNames
            .filter { names.contains($0) }
            .enumerated()
            .map { index, name in Part(name: name, order: index, colorIndex: index) }
    }
}
