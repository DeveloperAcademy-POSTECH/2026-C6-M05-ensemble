//
//  ScriptCueMatcher.swift
//  CueFlow
//
//  큐(트리거) 글로 대본에서 그 순간의 줄을 찾는다. 저장하지 않고 볼 때마다 계산한다.
//  - 트리거가 배역 이름으로 시작하면 ("판틴 - 공장 다툼 중") 그 배역의 대사 중에서 찾는다
//  - 나머지 단어("공장", "다툼")가 가장 많이 들어간 줄. 없으면 그 배역의 다음 대사
//  - 큐 순서 = 대본 순서: 앞 큐가 찾은 줄부터 뒤에서만 찾는다
//

import Foundation

enum ScriptCueMatcher {
    // 트리거에 흔히 붙는 말 (줄 찾을 때 무시)
    private static let ignoredWords: Set<String> = ["시", "중", "후", "전", "직후", "직전", "시작", "끝", "때", "다음", "이후", "부분"]

    // 트리거마다 찾은 줄 id (트리거 id → 줄 id). 못 찾은 트리거는 빠진다
    static func match(triggers: [Trigger], lines: [ScriptLine], castNames: [String]) -> [UUID: UUID] {
        var result: [UUID: UUID] = [:]
        var start = 0   // 앞 큐가 찾은 줄 다음부터

        // 대본에 실제로 말하는 사람 + 배역 목록. 긴 이름 먼저 ("공장장"이 "공장"보다 먼저)
        let names = Set(castNames + lines.compactMap(\.speaker)).sorted { $0.count > $1.count }

        for trigger in triggers {
            guard start < lines.count else { break }
            let text = trigger.text
            let speaker = names.first { text.hasPrefix($0) }

            // 이름 · 구분 기호를 뺀 나머지 단어
            let rest = speaker.map { String(text.dropFirst($0.count)) } ?? text
            let words = rest
                .split(whereSeparator: { $0.isWhitespace || "-–—:·,.()".contains($0) })
                .map(String.init)
                .filter { !ignoredWords.contains($0) }

            let candidates = Array(lines.indices[start...])
            let speakerLines = candidates.filter { speaker == nil || lines[$0].speaker == speaker }

            func score(_ index: Int) -> Int {
                words.filter { lines[index].text.contains($0) }.count
            }

            // 단어가 가장 많이 겹치는 줄 (같으면 앞쪽)
            let best = speakerLines.max { score($0) < score($1) || (score($0) == score($1) && $0 > $1) }
            var found: Int?
            if let best, score(best) > 0 {
                found = best
            } else if let speaker {
                // 단어는 안 겹치지만 배역이 있으면: 그 배역의 다음 대사, 대사가 없으면 이름이 나오는 줄
                found = speakerLines.first ?? candidates.first { lines[$0].text.contains(speaker) }
            }

            if let found {
                result[trigger.id] = lines[found].id
                start = found   // 같은 줄에 큐가 여러 개일 수 있어서 그 줄부터
            }
        }
        return result
    }
}
