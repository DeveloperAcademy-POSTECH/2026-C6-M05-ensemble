//
//  StageCueMoves.swift
//  CueFlow
//
//  큐를 따라 미니맵의 배역 · 소품 옮기기.
//  장면 배치(없으면 최초 상태)에서 시작해서, 지금 큐까지 차례로 큐를 적용한다.
//  - 소품 파트 큐: 제목에 있는 소품 이름 → 그 큐 위치로
//  - 무대 파트 큐: 제목에 있는 배역 이름 → 그 큐 위치로 (등장 · 퇴장)
//  - 의상 · 조명 · 음향 큐는 옮기지 않는다 ("판틴 공장복 착용 확인"은 판틴을 안 옮김)
//  무대 큐는 9구역(Cue.stageCell)을 정했으면 그 구역 가운데로, 안 정했으면 무대 가운데로.
//

import Foundation

extension StageArea {
    // 큐 위치 → 미니맵 구역. 콘솔은 무대 밖이라 없음
    init?(_ position: CuePosition) {
        switch position {
        case .sangsu: self = .sangsu
        case .hasu: self = .hasu
        case .stage: self = .stage
        case .console: return nil
        }
    }
}

enum StageCueMoves {
    // 지금 큐(트리거)까지 적용한 미니맵
    static func marks(
        start: [StageMark], triggers: [Trigger], through currentIndex: Int, production: Production
    ) -> [StageMark] {
        var marks = start
        for trigger in triggers.prefix(currentIndex + 1) {
            for cue in (trigger.cues ?? []).sorted(by: { $0.order < $1.order }) {
                apply(cue, to: &marks, production: production)
            }
        }
        return marks
    }

    // 이 큐가 옮기는 배역 · 소품 (파트로 배역인지 소품인지 정한다)
    static func movedNames(by cue: Cue, production: Production) -> [(String, StageItemKind)] {
        switch cue.part?.name {
        case "소품": names(in: cue.title, from: production.propNames).map { ($0, .prop) }
        case "무대": names(in: cue.title, from: production.castNames).map { ($0, .cast) }
        default: []
        }
    }

    private static func apply(_ cue: Cue, to marks: inout [StageMark], production: Production) {
        guard let area = StageArea(cue.position) else { return }
        let moved = movedNames(by: cue, production: production)

        for (index, (name, kind)) in moved.enumerated() {
            let existing = marks.firstIndex { $0.name == name && $0.kind == kind }
            var mark = existing.map { marks[$0] } ?? StageMark(name: name, kind: kind, area: area, x: 0.5, y: 0.5)
            // 한 큐에 여럿이면 옆으로 조금씩 비켜 놓는다
            let shift = (Double(index) - Double(moved.count - 1) / 2) * 0.07

            if area == .stage, let cell = cue.stageCell {
                mark.x = (Double(cell % 3) + 0.5) / 3 + shift
                mark.y = (Double(cell / 3) + 0.5) / 3
            } else if mark.area != area || existing == nil {
                // 다른 구역에서 들어오면 구역 가운데. 같은 구역 안이면 자리 그대로
                mark.x = 0.5 + shift
                mark.y = 0.5
            }
            mark.area = area
            mark.x = min(max(mark.x, 0.08), 0.92)

            if let existing {
                marks[existing] = mark
            } else {
                marks.append(mark)
            }
        }
    }

    // 제목에서 찾은 이름. "공장장"을 찾았으면 그 안의 "공장"은 뺀다. "노동자들"은 "노동자"로도 찾는다
    private static func names(in title: String, from names: [String]) -> [String] {
        let found = names.filter { name in
            title.contains(name) || (name.hasSuffix("들") && name.count > 2 && title.contains(name.dropLast()))
        }
        return found.filter { name in
            !found.contains { $0 != name && $0.contains(name) }
        }
    }
}
