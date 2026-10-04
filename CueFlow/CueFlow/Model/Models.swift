//
//  Models.swift
//  CueFlow
//
//  큐는 씬이 아니라 트리거에 붙는다. 같은 트리거에 붙은 큐 = 동시에 실행.
//  모든 데이터는 CueStore의 평평한 배열에 있고 ID로 서로를 가리킨다.
//

import Foundation

// 파트 = 메인 화면의 열 (무대, 조명, 음향 …). "파트 +"로 추가할 수 있다.
struct Part: Identifiable, Hashable {
    let id = UUID()
    var name: String
}

// 팀원. 확인 현황과 댓글 작성자에 쓰인다.
struct Member: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var partID: Part.ID
}

// SwiftUI의 Scene과 이름이 겹치지 않도록 ShowScene
struct ShowScene: Identifiable {
    let id = UUID()
    var name: String
}

// 씬 안의 트리거 (예: "배우 A 퇴장"). 순서는 트리거가 가진다.
struct Trigger: Identifiable {
    let id = UUID()
    var sceneID: ShowScene.ID
    var text: String
    var order: Int
}

struct Comment: Identifiable {
    let id = UUID()
    var authorID: Member.ID
    var text: String
    var createdAt: Date
}

struct Cue: Identifiable {
    let id = UUID()
    var triggerID: Trigger.ID
    var partID: Part.ID
    var action: String
    var order: Int                          // 같은 칸(파트 × 트리거) 안에서의 순서
    var checkedBy: Set<Member.ID> = []      // 이 큐를 확인한 팀원
    var comments: [Comment] = []
}
