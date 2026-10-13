//
//  RehearsalPreviewData.swift
//  CueFlow
//
//  미리보기(Preview) 전용 예시 데이터. 실제 앱 데이터에는 들어가지 않는다.
//

import Foundation

private extension Part {
    // 기본 파트 5개 (이름 → 파트)
    static var samples: [String: Part] {
        let names = ["무대", "소품", "의상", "조명", "음향"]
        return Dictionary(uniqueKeysWithValues: names.enumerated().map { index, name in
            (name, Part(name: name, order: index, colorIndex: index))
        })
    }
}

enum RehearsalPreviewData {
    // 레미제라블 + 장면 5개. 첫 장면(시장 등장)에 피그마 예시 큐가 들어 있다.
    static var production: Production {
        let production = Production(title: "레미제라블", genre: "뮤지컬", firstShowDate: Date())
        let scenes: [(String, SceneKind)] = [
            ("시장 등장", .scene),
            ("At the End of the Day", .number),
            ("공장 앞 거리", .transition),
            ("판틴의 몰락", .scene),
            ("I Dreamed a Dream", .number),
        ]
        production.scenes = scenes.enumerated().map { index, item in
            ShowScene(title: item.0, kind: item.1, order: index)
        }
        let parts = Part.samples
        production.parts = Array(parts.values)
        production.scenes?.first?.triggers = sampleTriggers(parts: parts)
        production.scenes?.first?.scriptLines = scriptLines
        production.castNames = ["판틴", "공장장", "시장", "노동자들"]
        production.propNames = ["로켓", "편지", "작업대"]
        return production
    }

    // 미리보기에서 바로 쓰는 첫 장면의 큐
    static var sceneCues: [Cue] {
        sampleTriggers(parts: Part.samples).flatMap { $0.cues ?? [] }
    }

    // 피그마 큐 목록 (S#3 시장 등장): 트리거 3개, 큐 5개
    private static func sampleTriggers(parts: [String: Part]) -> [Trigger] {
        var nextOrder = 0   // 트리거 안 순서가 섞이지 않게 차례로 번호
        func cue(_ title: String, _ position: CuePosition, _ part: String, cell: Int? = nil) -> Cue {
            nextOrder += 1
            let cue = Cue(title: title, position: position, order: nextOrder)
            cue.part = parts[part]
            cue.stageCell = cell
            return cue
        }

        let first = Trigger(text: "공장 넘버 전주", order: 0)
        first.cues = [
            cue("공장 전체조명 ON", .stage, "조명", cell: 4),
            cue("판틴 공장복 착용 확인", .sangsu, "의상"),
            cue("공장 노동자 입장", .sangsu, "무대"),
        ]
        let second = Trigger(text: "노동자들 - 후렴 직후", order: 1)
        second.cues = [cue("시장 공장 등장", .stage, "무대", cell: 1)]

        let third = Trigger(text: "판틴 - 공장 다툼 중", order: 2)
        third.cues = [cue("판틴 로켓, 편지", .stage, "소품")]   // 칸 미정

        return [first, second, third]
    }

    // 피그마 예시 대본 (시장 등장) — 대본 패널 미리보기용
    static var scriptLines: [ScriptLine] {
        ScriptParser.parse(sampleScriptText, cast: ["판틴", "공장장"])
            .first?.lines
            .enumerated()
            .map { index, line in ScriptLine(order: index, speaker: line.speaker, text: line.text) } ?? []
    }

    // 대본 입력 창 미리보기용 글 (구글 닥스에서 붙여넣은 모양)
    // 앱의 예시 공연엔 씬 3개 · 넘버 2개 → S5는 "새 장면으로 만들어요"로 보인다
    static let sampleScriptText = """
    S1 (하루가 끝날 무렵, 공장 안…)
    판틴 (편지를 품에 급히 숨기며 작게) …아무것도 아니에요. 그냥 집에서 온 편지예요.
    공장장 (작업대를 탕 치며, 노동자들을 둘러보고) 일하는 시간에 편지라니! 여기가 무슨 우체국인 줄 알아? 다들 손 멈추지 말고 계속해! 판틴, 너는 이리 와.
    판틴 죄송해요… 금방 다시 일할게요. 제발 한 번만 봐주세요. (동료들의 시선을 피하며 고개를 숙이고)
    공장장 딸이 있다는 소문이 사실이었군. 오늘까지만 일하고 나가.
    판틴 (로켓을 꼭 움켜쥔다. 떨리는 목소리로) …제가 일을 못 하면 그 아이는 어떻게 되나요. 제발요.
    공장장 사정은 알 바 아니야. 이 공장에 흠 있는 사람 자리는 없어!

    N1 At the End of the Day - 노동자들 합창. 더 거칠게.
    노동자들 하루가 또 끝나고 (주먹을 쥐고 앞으로
    한 걸음씩 걸어 나온다)
    공장장 다들 자리로 돌아가!

    S5 공장 앞 거리
    판틴 (혼자 남아 편지를 다시 펼친다) 조금만 기다려, 금방 갈게.
    """
}
