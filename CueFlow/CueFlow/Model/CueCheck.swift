//
//  CueCheck.swift
//  CueFlow
//
//  확인 = 멤버가 큐를 확인했다는 기록 (카드의 ✓ 숫자, "미확인" 계산에 쓰인다).
//  큐 안에 몰아 저장하지 않고 따로 두는 이유: 여러 사람이 동시에 확인해도 서로 덮어쓰지 않게.
//

import Foundation
import SwiftData

@Model
final class CueCheck {
    var id: UUID = UUID()
    var checkedAt: Date = Date()

    var cue: Cue?                       // 어느 큐를
    var member: Member?                 // 누가 확인했는지

    init() {}
}
