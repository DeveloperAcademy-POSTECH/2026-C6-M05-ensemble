//
//  ScriptLine.swift
//  CueFlow
//
//  대본 한 줄. 장면(ShowScene)마다 순서대로 들어간다.
//  배역이 있으면 대사 줄, 없으면 지문 줄. 괄호 지문은 글 안에 그대로 둔다 (예: "(팔뚝을 만지며) 에구구,").
//

import Foundation
import SwiftData

@Model
final class ScriptLine {
    var id: UUID = UUID()
    var order: Int = 0              // 장면 안에서 몇 번째 줄인지
    var speaker: String?            // 배역 이름 (예: "우현"). 비어 있으면 지문 줄
    var text: String = ""           // 대사 또는 지문. 괄호 지문 포함

    var scene: ShowScene?           // 어느 장면의 대본인지

    init(order: Int, speaker: String?, text: String) {
        self.order = order
        self.speaker = speaker
        self.text = text
    }
}
