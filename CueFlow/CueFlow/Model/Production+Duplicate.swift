//
//  Production+Duplicate.swift
//  CueFlow
//
//  Created by 김나현 on 11/14/26.
//
//  홈 우클릭 > 프로젝트 복제: 큐시트 내용만 그대로 복사한 새 공연을 만든다.
//  복사: 공연 정보 · 파트 · 씬 · 트리거 · 큐 · 대본 · 무대 배치
//  복사 안 함: 초대된 사람(멤버) · 공지 · 댓글 · 큐 확인 · 수정 기록 → 새 공연은 나만 있는 내 공연
//

import Foundation
import SwiftData

extension Production {
    @discardableResult
    func duplicate(in context: ModelContext) -> Production {
        let copy = Production(title: "\(title) 사본", genre: genre, firstShowDate: firstShowDate)
        context.insert(copy)
        copy.lastShowDate = lastShowDate
        copy.venue = venue
        copy.seatCount = seatCount
        copy.organizer = organizer
        copy.runningTime = runningTime
        copy.castNames = castNames
        copy.propNames = propNames
        copy.stageGridColumns = stageGridColumns

        let partMap = copyParts(to: copy, in: context)
        for scene in scenes ?? [] {
            scene.duplicate(to: copy, partMap: partMap, in: context)
        }
        for placement in initialPlacements ?? [] {
            placement.duplicate(in: context).production = copy
        }
        return copy
    }

    // 옛 파트 id → 새 파트 (큐를 같은 파트에 다시 붙이려고)
    private func copyParts(to copy: Production, in context: ModelContext) -> [UUID: Part] {
        var map: [UUID: Part] = [:]
        for part in parts ?? [] {
            let newPart = Part(name: part.name, order: part.order, colorIndex: part.colorIndex)
            context.insert(newPart)
            newPart.production = copy
            map[part.id] = newPart
        }
        return map
    }
}

extension ShowScene {
    // 씬 + 안의 트리거 · 큐 · 대본 · 무대 배치
    fileprivate func duplicate(to production: Production, partMap: [UUID: Part], in context: ModelContext) {
        let copy = ShowScene(title: title, kind: kind, order: order)
        context.insert(copy)
        copy.production = production
        copy.hasOwnPlacements = hasOwnPlacements

        for trigger in triggers ?? [] {
            trigger.duplicate(to: copy, partMap: partMap, in: context)
        }
        for line in scriptLines ?? [] {
            let newLine = ScriptLine(order: line.order, speaker: line.speaker, text: line.text)
            context.insert(newLine)
            newLine.scene = copy
        }
        for placement in placements ?? [] {
            placement.duplicate(in: context).scene = copy
        }
    }
}

extension Trigger {
    // 트리거 + 안의 큐 (댓글 · 확인 · 수정 기록은 빼고)
    fileprivate func duplicate(to scene: ShowScene, partMap: [UUID: Part], in context: ModelContext) {
        let copy = Trigger(text: text, order: order)
        context.insert(copy)
        copy.scene = scene

        for cue in cues ?? [] {
            let newCue = Cue(title: cue.title, position: cue.position, order: cue.order)
            context.insert(newCue)
            newCue.stageCell = cue.stageCell
            newCue.part = cue.part.flatMap { partMap[$0.id] }
            newCue.trigger = copy
        }
    }
}

extension StagePlacement {
    fileprivate func duplicate(in context: ModelContext) -> StagePlacement {
        let copy = StagePlacement(name: name, kind: kind, area: area, x: x, y: y)
        context.insert(copy)
        return copy
    }
}
