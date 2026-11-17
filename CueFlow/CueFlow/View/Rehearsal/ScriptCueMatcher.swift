//
//  ScriptCueMatcher.swift
//  CueFlow
//
//  큐(트리거) 글로 대본에서 그 순간의 줄을 찾는다. 저장하지 않고 볼 때마다 계산한다.
//  - 줄마다 점수: 트리거 단어("공장", "다툼")가 얼마나 들어 있나 + 배역 이름이 맞나
//    · 단어는 글자가 통째로 같으면 만점, 아니면 자모로 쪼개 겹치는 만큼 ("다툼" ↔ "다투다가")
//    · 배역은 거르는 조건이 아니라 가산점 (그 배역 대사 > 이름이 나오는 지문)
//  - 큐 순서 = 대본 순서: 장면 전체를 한꺼번에 놓고, 순서를 지키면서 점수 합이 가장 큰 배치를 고른다
//    → 앞 큐 하나가 틀려도 뒤 큐들이 같이 밀리지 않는다 (#227)
//  - 단어로 못 찾은 큐는 앞뒤 큐 사이에 둔다 (배역이 있으면 그 배역의 다음 대사)
//

import Foundation

enum ScriptCueMatcher {
    // 트리거에 흔히 붙는 말 · 조사 (줄 찾을 때 무시)
    private static let ignoredWords: Set<String> = [
        "시", "중", "후", "전", "직후", "직전", "시작", "끝", "때", "다음", "이후", "부분",
        "이", "가", "을", "를", "은", "는", "의", "에", "와", "과", "도", "로", "으로", "에서",
    ]
    private static let separators = "-–—:·,.()[]~!?\"'“”‘’/…"

    // 점수 (정수로 계산해 같은 점수 비교가 정확하게)
    private static let exactWord = 100       // 단어가 그대로 들어 있음
    private static let partialWord = 80      // 자모가 전부 겹칠 때 최대 점수 (겹친 비율만큼)
    private static let minPartialRatio = 0.5 // 이보다 덜 겹치면 0점
    private static let speakerLine = 60      // 그 배역의 대사 줄
    private static let speakerMention = 40   // 그 배역 이름이 나오는 줄 (지문 등)
    private static let minScore = 40         // 이 점수는 넘어야 "찾았다"

    // 트리거마다 찾은 줄 id (트리거 id → 줄 id). 대본이 비었으면 빈 결과
    static func match(triggers: [Trigger], lines: [ScriptLine], castNames: [String]) -> [UUID: UUID] {
        let placed = place(
            triggerTexts: triggers.map(\.text),
            lines: lines.map { (speaker: $0.speaker, text: $0.text) },
            castNames: castNames
        )
        var result: [UUID: UUID] = [:]
        for (trigger, index) in zip(triggers, placed) {
            if let index { result[trigger.id] = lines[index].id }
        }
        return result
    }

    // 트리거마다 대본 몇 번째 줄인지 (순서 그대로)
    static func place(triggerTexts: [String], lines: [(speaker: String?, text: String)], castNames: [String]) -> [Int?] {
        let n = triggerTexts.count, m = lines.count
        guard n > 0, m > 0 else { return Array(repeating: nil, count: n) }

        // 대본에 실제로 말하는 사람 + 배역 목록. 긴 이름 먼저 ("공장장"이 "공장"보다 먼저)
        let names = Set(castNames + lines.compactMap(\.speaker))
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }

        let queries = triggerTexts.map { Query($0, names: names) }
        let texts = lines.map { compact($0.text) }
        let grams = texts.map { trigrams(of: $0) }

        // 점수표: score[트리거][줄]
        var score = Array(repeating: Array(repeating: 0, count: m), count: n)
        for i in 0..<n {
            for j in 0..<m {
                let s = queries[i].score(speaker: lines[j].speaker, text: texts[j], grams: grams[j])
                score[i][j] = s >= minScore ? s : 0
            }
        }

        // best[i][j] = 앞에서 i개 트리거를 0...j 줄 안에 순서대로 놓았을 때 점수 합의 최대
        // (같은 줄에 큐가 여러 개일 수 있어서 앞 트리거와 같은 줄도 된다)
        var best = Array(repeating: Array(repeating: 0, count: m), count: n + 1)
        for i in 1...n {
            for j in 0..<m {
                let left = j > 0 ? best[i][j - 1] : 0
                best[i][j] = max(left, best[i - 1][j] + score[i - 1][j])
            }
        }

        // 뒤에서부터 되짚기. 점수가 같으면 앞쪽 줄
        var placed = [Int?](repeating: nil, count: n)
        var i = n, j = m - 1
        while i > 0 {
            if j > 0 && best[i][j] == best[i][j - 1] {
                j -= 1
                continue
            }
            if score[i - 1][j] > 0 && best[i][j] == best[i - 1][j] + score[i - 1][j] {
                placed[i - 1] = j
            }
            i -= 1
        }

        // 못 찾은 트리거: 앞 큐 다음 줄부터 뒤 큐 줄 사이 (배역이 있으면 그 배역의 대사 먼저)
        var previous = -1
        for i in 0..<n {
            if let found = placed[i] {
                previous = found
                continue
            }
            let next = placed[(i + 1)...].lazy.compactMap { $0 }.first ?? m - 1
            let from = min(previous + 1, next)
            var found = from
            if let speaker = queries[i].speaker,
               let line = (from...next).first(where: { lines[$0].speaker == speaker }) {
                found = line
            }
            placed[i] = found
            previous = found
        }
        return placed
    }

    // MARK: - 트리거 글 하나

    private struct Query {
        let speaker: String?
        let words: [(text: String, grams: Set<String>)]

        init(_ text: String, names: [String]) {
            // 배역 이름: 앞에 붙은 이름 먼저, 없으면 글 안에 나오는 이름
            let speaker = names.first { text.hasPrefix($0) } ?? names.first { text.contains($0) }
            let rest = speaker.map { text.replacingOccurrences(of: $0, with: " ") } ?? text
            self.speaker = speaker
            self.words = rest
                .split(whereSeparator: { $0.isWhitespace || ScriptCueMatcher.separators.contains($0) })
                .map(String.init)
                .filter { !ScriptCueMatcher.ignoredWords.contains($0) }
                .map(ScriptCueMatcher.compact)
                .filter { !$0.isEmpty }
                .map { (text: $0, grams: ScriptCueMatcher.trigrams(of: $0)) }
        }

        func score(speaker lineSpeaker: String?, text: String, grams: Set<String>) -> Int {
            var total = 0
            for word in words {
                if text.contains(word.text) {
                    total += ScriptCueMatcher.exactWord
                } else if word.grams.count > 1 {
                    // 자모 세 개씩 묶음이 얼마나 겹치나 ("다툼" ㄷㅏㅌ·ㅏㅌㅜ·ㅌㅜㅁ ↔ "다투다가" → 2/3)
                    let ratio = Double(word.grams.intersection(grams).count) / Double(word.grams.count)
                    if ratio >= ScriptCueMatcher.minPartialRatio {
                        total += Int(ratio * Double(ScriptCueMatcher.partialWord))
                    }
                }
            }
            if let speaker {
                if lineSpeaker == speaker {
                    total += ScriptCueMatcher.speakerLine
                } else if text.contains(ScriptCueMatcher.compact(speaker)) {
                    total += ScriptCueMatcher.speakerMention
                }
            }
            return total
        }
    }

    // MARK: - 글자 다듬기

    // 띄어쓰기 · 기호를 빼고 글자 · 숫자만
    private static func compact(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
        return String(scalars)
    }

    // 한글을 자모로 쪼갠 뒤 세 개씩 묶음 ("다툼" → ㄷㅏㅌ, ㅏㅌㅜ, ㅌㅜㅁ)
    private static func trigrams(of compacted: String) -> Set<String> {
        let jamo = Array(compacted.decomposedStringWithCanonicalMapping.unicodeScalars)
        guard jamo.count >= 3 else { return [] }
        var result = Set<String>()
        for start in 0...(jamo.count - 3) {
            var gram = String.UnicodeScalarView()
            gram.append(contentsOf: jamo[start..<(start + 3)])
            result.insert(String(gram))
        }
        return result
    }
}
