//
//  CueStore.swift
//  CueFlow
//
//  앱 전체가 함께 보는 데이터. CueFlowApp에서 하나 만들어 .environment로 내려준다.
//  화면에서는 @Environment(CueStore.self) var store 로 꺼내 쓴다.
//

import Foundation
import Observation

@Observable
class CueStore {
    var showTitle = ""
    var parts: [Part] = []
    var members: [Member] = []
    var scenes: [ShowScene] = []
    var triggers: [Trigger] = []
    var cues: [Cue] = []

    var selectedPartID: Part.ID?            // 파트 필터. nil = 전체
    var currentMemberID: Member.ID?         // 지금 앱을 쓰는 사람 (확인·댓글 작성자). 유저테스트용으로 고정

    // MARK: - 조회

    // 필터를 거친, 지금 화면에 보여줄 파트(행)
    var visibleParts: [Part] {
        guard let selectedPartID else { return parts }
        return parts.filter { $0.id == selectedPartID }
    }

    func part(_ id: Part.ID) -> Part? {
        parts.first { $0.id == id }
    }

    func member(_ id: Member.ID) -> Member? {
        members.first { $0.id == id }
    }

    func cue(_ id: Cue.ID) -> Cue? {
        cues.first { $0.id == id }
    }

    func trigger(_ id: Trigger.ID) -> Trigger? {
        triggers.first { $0.id == id }
    }

    // 파트 행 헤더의 "총 N개"
    func cueCount(partID: Part.ID) -> Int {
        cues.filter { $0.partID == partID }.count
    }

    // 씬 안의 트리거를 순서대로
    func triggers(in sceneID: ShowScene.ID) -> [Trigger] {
        triggers.filter { $0.sceneID == sceneID }.sorted { $0.order < $1.order }
    }

    // 트리거 화면의 한 칸 (파트 × 트리거)
    func cues(partID: Part.ID, triggerID: Trigger.ID) -> [Cue] {
        cues.filter { $0.partID == partID && $0.triggerID == triggerID }.sorted { $0.order < $1.order }
    }

    // 메인 화면의 한 칸 (파트 × 씬): 트리거 순서 → 칸 안 순서대로 (트리거, 큐) 쌍
    func cuePairs(partID: Part.ID, sceneID: ShowScene.ID) -> [(trigger: Trigger, cue: Cue)] {
        triggers(in: sceneID).flatMap { t in
            cues(partID: partID, triggerID: t.id).map { (trigger: t, cue: $0) }
        }
    }

    // 확인 현황: 전체 팀원을 확인한 사람 / 아직 안 한 사람으로 나눔
    func checkStatus(of cueID: Cue.ID) -> (checked: [Member], unchecked: [Member]) {
        let checkedIDs = cue(cueID)?.checkedBy ?? []
        return (members.filter { checkedIDs.contains($0.id) },
                members.filter { !checkedIDs.contains($0.id) })
    }

    // MARK: - 추가 / 변경

    @discardableResult
    func addScene(name: String, subtitle: String = "") -> ShowScene {
        let scene = ShowScene(name: name, subtitle: subtitle)
        scenes.append(scene)
        return scene
    }

    @discardableResult
    func addPart(name: String) -> Part {
        let part = Part(name: name)
        parts.append(part)
        return part
    }

    // nil을 넣으면 전체 보기
    func selectPart(_ partID: Part.ID?) {
        selectedPartID = partID
    }

    // 같은 글자 트리거가 있으면 재사용, 없으면 새로 추가
    // afterID가 있으면 그 트리거 바로 뒤에, 없으면 맨 뒤에 넣음 (새로 만들 때만 적용)
    func findOrCreateTrigger(text: String, sceneID: ShowScene.ID, after afterID: Trigger.ID? = nil) -> Trigger {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let existing = triggers.first(where: { $0.sceneID == sceneID && $0.text == trimmed }) {
            return existing
        }
        var order = triggers(in: sceneID).count + 1
        if let after = triggers.first(where: { $0.id == afterID && $0.sceneID == sceneID }) {
            order = after.order + 1
            // 뒤에 있던 트리거들은 한 칸씩 밀기
            for i in triggers.indices where triggers[i].sceneID == sceneID && triggers[i].order >= order {
                triggers[i].order += 1
            }
        }
        let new = Trigger(sceneID: sceneID, text: trimmed, order: order)
        triggers.append(new)
        return new
    }

    // 큐 추가 = 트리거 찾거나 만들고 + 큐 붙이기
    @discardableResult
    func addCue(sceneID: ShowScene.ID, triggerText: String, partID: Part.ID, action: String,
                position: StageSide? = nil, after afterID: Trigger.ID? = nil) -> Cue {
        let trigger = findOrCreateTrigger(text: triggerText, sceneID: sceneID, after: afterID)
        let order = cues(partID: partID, triggerID: trigger.id).count + 1
        let cue = Cue(triggerID: trigger.id, partID: partID, action: action, position: position, order: order)
        cues.append(cue)
        return cue
    }

    func toggleCheck(cueID: Cue.ID, memberID: Member.ID) {
        guard let idx = cues.firstIndex(where: { $0.id == cueID }) else { return }
        if cues[idx].checkedBy.contains(memberID) {
            cues[idx].checkedBy.remove(memberID)
        } else {
            cues[idx].checkedBy.insert(memberID)
        }
    }

    // parentID를 넣으면 그 댓글의 답글로 달린다
    func addComment(cueID: Cue.ID, authorID: Member.ID, text: String, at date: Date = .now,
                    parentID: Comment.ID? = nil) {
        guard let idx = cues.firstIndex(where: { $0.id == cueID }) else { return }
        cues[idx].comments.append(Comment(authorID: authorID, text: text, createdAt: date, parentID: parentID))
    }
}
