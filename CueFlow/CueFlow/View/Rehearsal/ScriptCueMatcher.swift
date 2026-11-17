//
//  ScriptCueMatcher.swift
//  CueFlow
//
//  큐(트리거) 글로 대본에서 그 순간의 줄을 찾는다. 저장하지 않고 볼 때마다 계산한다.
//  - 줄마다 점수: 트리거 단어("공장", "다툼")가 얼마나 들어 있나 + 배역 이름이 맞나
//    · 단어는 글자가 통째로 같으면 만점, 아니면 자모로 쪼개 겹치는 만큼 ("다툼" ↔ "다투다가")
//    · 긴 단어일수록 점수가 크다 ("또" · "왜" 같은 한 글자는 여기저기 나와서 작게)
//    · 배역은 단어가 맞은 줄에만 붙는 가산점 (그 배역 대사 > 이름이 나오는 지문)
//  - PDF에서 가져온 대본은 대사 한 줄이 여러 줄로 쪼개져 있어서 ("편안하" / "게 자자") 다음 줄까지 이어 붙여서도 본다
//  - 트리거는 하나씩 따로 찾는다. 트리거 순서 · 큐 번호가 대본 순서와 다를 때가 많아서 순서는 쓰지 않는다 (#227)
//  - 단어가 하나도 안 맞으면 못 찾은 것 (엉뚱한 줄을 강조하지 않게)
//

import Foundation

enum ScriptCueMatcher {
    // 트리거에 흔히 붙는 말 · 조사 (줄 찾을 때 무시)
    private static let ignoredWords: Set<String> = [
        "시", "중", "후", "전", "직후", "직전", "시작", "끝", "때", "다음", "이후", "부분", "되면", "하면", "씬", "장면",
        "이", "가", "을", "를", "은", "는", "의", "에", "와", "과", "도", "로", "으로", "에서",
    ]
    private static let separators = "-–—:·,.()[]~!?\"'“”‘’/…"

    private static let minPartialRatio = 0.5 // 자모가 이보다 덜 겹치면 0점
    private static let minCoverage = 0.5     // 트리거 단어가 이만큼은 맞아야 찾은 것
    private static let speakerLine = 40      // 그 배역의 대사 줄
    private static let speakerMention = 20   // 그 배역 이름이 나오는 줄 (지문 등)

    // 트리거마다 찾은 줄 id (트리거 id → 줄 id). 못 찾은 트리거는 빠진다
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

    // 트리거마다 대본 몇 번째 줄인지 (트리거 순서 그대로). 못 찾으면 nil
    static func place(triggerTexts: [String], lines: [(speaker: String?, text: String)], castNames: [String]) -> [Int?] {
        guard !lines.isEmpty else { return Array(repeating: nil, count: triggerTexts.count) }

        // 배역 이름. 배역 목록이 있으면 그것만 (PDF 줄바꿈 탓에 "는" · "게" 같은 말이 말하는 사람으로 들어간 줄이 있어서)
        // 긴 이름 먼저 ("공장장"이 "공장"보다 먼저)
        let names = Set(castNames.isEmpty ? lines.compactMap(\.speaker) : castNames)
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }

        // 줄 글 (그 줄만 / 다음 줄까지 이어 붙인 것)
        let own = lines.map { compact($0.text) }
        let joined = own.indices.map { $0 + 1 < own.count ? own[$0] + own[$0 + 1] : own[$0] }
        let ownGrams = own.map { trigrams(of: $0) }
        let joinedGrams = joined.map { trigrams(of: $0) }

        return triggerTexts.map { text in
            // "씬 시작" · "장면 시작" = 대본 첫 줄
            let flat = text.replacingOccurrences(of: " ", with: "")
            if flat.contains("씬시작") || flat.contains("장면시작") { return 0 }

            let query = Query(text, names: names)
            guard !query.words.isEmpty else { return nil }

            var best: (index: Int, score: Int)?
            for j in lines.indices {
                // 이어 붙인 쪽은 1점 깎아서, 같은 점수면 문장이 실제로 있는 줄이 이긴다
                let score = max(
                    query.score(speaker: lines[j].speaker, text: own[j], grams: ownGrams[j]),
                    query.score(speaker: lines[j].speaker, text: joined[j], grams: joinedGrams[j]) - 1
                )
                if score > (best?.score ?? 0) { best = (j, score) }   // 같은 점수면 앞쪽 줄
            }
            return best?.index
        }
    }

    // MARK: - 트리거 글 하나

    private struct Query {
        let speaker: String?
        let words: [(text: String, grams: Set<String>, firstGram: String, weight: Int)]
        var totalWeight: Int { words.reduce(0) { $0 + $1.weight } }

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
                .map { (text: $0, grams: ScriptCueMatcher.trigrams(of: $0), firstGram: ScriptCueMatcher.firstTrigram(of: $0),
                        weight: min($0.count, 4) * 30) }
        }

        // 트리거 단어(무게 기준)가 절반도 안 맞으면 0 → "얼른" 하나만 겹치는 줄 같은 엉뚱한 줄을 고르지 않는다
        // 배역 이름만으로는 찾지 않는다
        func score(speaker lineSpeaker: String?, text: String, grams: Set<String>) -> Int {
            var total = 0
            for word in words {
                if text.contains(word.text) {
                    total += word.weight
                } else if word.grams.count > 1, grams.contains(word.firstGram) {
                    // 앞부분(첫 자모 묶음)이 같고, 자모 세 개씩 묶음이 얼마나 겹치나
                    // ("다툼" ㄷㅏㅌ·ㅏㅌㅜ·ㅌㅜㅁ ↔ "다투다가" → 2/3). 한국어는 말끝이 바뀌니까 앞이 같아야 한다
                    let ratio = Double(word.grams.intersection(grams).count) / Double(word.grams.count)
                    if ratio >= ScriptCueMatcher.minPartialRatio {
                        total += Int(ratio * Double(word.weight) * 0.8)
                    }
                }
            }
            guard total > 0, Double(total) >= Double(totalWeight) * ScriptCueMatcher.minCoverage else { return 0 }
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

    // 단어 맨 앞 자모 세 개 ("다툼" → ㄷㅏㅌ)
    private static func firstTrigram(of compacted: String) -> String {
        var gram = String.UnicodeScalarView()
        gram.append(contentsOf: compacted.decomposedStringWithCanonicalMapping.unicodeScalars.prefix(3))
        return String(gram)
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
