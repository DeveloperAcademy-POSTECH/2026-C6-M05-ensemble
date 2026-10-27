//
//  ShowScene+Rehearsal.swift
//  CueFlow
//
//  리허설 모드에 보여줄 장면 이름.
//

import Foundation

extension SceneKind {
    // 장면 번호 앞 글자: 씬 S, 넘버 N, 전환 D
    var codePrefix: String {
        switch self {
        case .scene: "S"
        case .number: "N"
        case .transition: "D"
        }
    }
}

extension ShowScene {
    // "S#3 시장 등장". 번호는 같은 종류(씬/넘버/전환)끼리 몇 번째인지.
    // scenes = 공연 흐름 순서로 정렬된 전체 장면
    func displayName(in scenes: [ShowScene]) -> String {
        "\(code(in: scenes)) \(title)"
    }

    // "S#3" (이름 없이 번호만). 큐 목록의 "S#3 - 1"에 쓴다.
    func code(in scenes: [ShowScene]) -> String {
        let sameKind = scenes.filter { $0.kind == kind }
        let number = (sameKind.firstIndex(of: self) ?? 0) + 1
        return "\(kind.codePrefix)#\(number)"
    }
}
