//
//  Trigger.swift
//  CueFlow
//
//  트리거 = 씬 안에서 큐가 실행되는 순간 (예: "자베르 - 첫 소절 시작 시").
//  같은 트리거에 붙은 큐 = 동시에 실행. 순서는 트리거가 가진다.
//

import Foundation
import SwiftData

@Model
final class Trigger {
    var id: UUID = UUID()
    var text: String = ""           // 카드 둘째 줄에 보이는 글
    var order: Int = 0              // 씬 안에서 몇 번째 순간인지

    var scene: ShowScene?           // 어느 씬 안의 트리거인지

    // 이 트리거에 붙은 큐들. 트리거를 지우면 큐도 같이 지운다.
    @Relationship(deleteRule: .cascade, inverse: \Cue.trigger)
    var cues: [Cue]? = []

    init(text: String, order: Int) {
        self.text = text
        self.order = order
    }
}
