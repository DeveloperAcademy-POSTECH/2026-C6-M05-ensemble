//
//  ShowScene.swift
//  CueFlow
//
//  씬 = 메인 화면의 열 (#1 Scene, #2 Scene …).
//  SwiftUI의 Scene과 이름이 겹치지 않도록 ShowScene.
//

import Foundation
import SwiftData

// 공연 흐름의 한 줄이 무엇인지. 씬 구성 화면의 씬 / 넘버 / 전환.
enum SceneKind: String, Codable, CaseIterable {
    case scene = "씬"         // S1, S2 …
    case number = "넘버"      // N1, N2 … (노래)
    case transition = "전환"  // D1, D2 … (장면 전환)
}

@Model
final class ShowScene {
    var id: UUID = UUID()
    var title: String = ""              // 예: "프롤로그 : 툴롱 노역장"
    var kind: SceneKind = SceneKind.scene
    var order: Int = 0                  // 공연 흐름에서 몇 번째인지 (왼쪽부터)

    var production: Production?         // 어느 공연의 씬인지

    // 이 씬 안의 트리거들. 씬을 지우면 트리거(와 그 큐)도 같이 지운다.
    @Relationship(deleteRule: .cascade, inverse: \Trigger.scene)
    var triggers: [Trigger]? = []

    init(title: String, kind: SceneKind, order: Int) {
        self.title = title
        self.kind = kind
        self.order = order
    }
}
