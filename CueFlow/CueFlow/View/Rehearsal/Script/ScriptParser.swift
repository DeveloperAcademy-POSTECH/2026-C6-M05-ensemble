//
//  ScriptParser.swift
//  CueFlow
//
//  붙여넣은 대본 글을 장면 / 배역 / 대사 / 지문으로 나누는 규칙.
//  - 줄 맨 앞 장면 표시 → 새 장면 시작 (씬 · 넘버 · 전환)
//      씬: S15 · S#15 · 씬 15 · Scene 15 · #15 · 15장 · 제15장
//      넘버: N10 · M10 · 넘버 10 · Number 10
//      전환: D3 · 전환 3
//  - 미리보기에서 사용자가 고친 것(SceneOverrides)이 위 규칙보다 먼저
//  - 줄 맨 앞 단어가 배역 목록에 있으면 → 배역 + 대사 ("우현 (팔뚝을 만지며) 에구구," / "우현: 에구구,")
//  - 그 외 줄 → 지문
//  - 괄호가 다음 줄까지 이어지면 한 줄로 합친다
//

import Foundation

// 나눈 결과: 장면 하나
struct ParsedScene: Identifiable {
    let id = UUID()
    var kind: SceneKind?      // nil = 첫 장면 표시 앞에 있던 글 → 지금 보고 있는 장면에 넣는다
    var number: Int = 0       // S15의 15
    var title: String = ""    // 장면 표시 뒤의 글 (예: "기쁨 ~ 리프라이즈 - 마지막 자장가.")
    var headingIndex: Int?    // 대본에 적힌 장면 표시의 문단 번호 (합치기용)
    var splitIndex: Int?      // 사용자가 "여기서 나누기"로 만든 장면이면 그 문단 번호 (나누기 취소용)
    var lines: [ParsedLine] = []

    var code: String {
        guard let kind else { return "" }
        return "\(kind.codePrefix)#\(number)"
    }
}

// 나눈 결과: 대본 한 줄
struct ParsedLine: Identifiable {
    let id = UUID()
    var index: Int         // 몇 번째 문단인지 (나누기용)
    var speaker: String?   // nil = 지문
    var text: String
}

// 미리보기에서 사용자가 고친 장면 나누기. 키는 문단 번호
struct SceneOverrides {
    var splits: [Int: SceneKind] = [:]   // 이 문단부터 새 장면
    var merged: Set<Int> = []            // 이 장면 표시는 무시하고 앞 장면에 합친다 (표시 줄은 지문으로 남김)
}

enum ScriptParser {
    // 글 → 문단 (빈 줄은 버리고, 괄호가 안 닫힌 줄은 다음 줄과 합친다)
    static func paragraphs(_ text: String) -> [String] {
        var result: [String] = []
        var buffer = ""
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty && buffer.isEmpty { continue }
            buffer = buffer.isEmpty ? line : buffer + " " + line

            let open = buffer.filter { $0 == "(" }.count
            let close = buffer.filter { $0 == ")" }.count
            if open <= close {
                result.append(buffer.trimmingCharacters(in: .whitespaces))
                buffer = ""
            }
        }
        if !buffer.isEmpty { result.append(buffer) }
        return result
    }

    // 장면 표시 모양들. 캡처 1 = 번호, 캡처 2 = 뒤의 글. 대소문자 무시
    private static let headingPatterns: [(Regex<(Substring, Substring, Substring?)>, SceneKind)] = [
        (/(?:S|씬|scene|#)\s?#?\s?(\d+)[.:]?(\s+.*)?/.ignoresCase(), SceneKind.scene),
        (/(?:제\s?)?(\d+)\s?장[.:]?(\s+.*)?/, SceneKind.scene),
        (/(?:N|M|넘버|number)\s?#?\s?(\d+)[.:]?(\s+.*)?/.ignoresCase(), SceneKind.number),
        (/(?:D|전환)\s?#?\s?(\d+)[.:]?(\s+.*)?/.ignoresCase(), SceneKind.transition),
    ]

    // "S15 장면 설명" → (씬, 15, "장면 설명"). 장면 표시가 아니면 nil
    static func heading(_ paragraph: String) -> (kind: SceneKind, number: Int, rest: String)? {
        for (pattern, kind) in headingPatterns {
            guard let match = paragraph.wholeMatch(of: pattern),
                  let number = Int(match.1) else { continue }
            let rest = (match.2.map(String.init) ?? "").trimmingCharacters(in: CharacterSet(charactersIn: " -–—:"))   // "Scene 2 - 거리" → "거리"
            return (kind, number, rest)
        }
        return nil
    }

    // 줄 맨 앞 단어 (배역 후보). "우현:" 의 콜론은 뗀다. 괄호로 시작하면 지문이라 nil
    static func firstWord(_ paragraph: String) -> String? {
        guard !paragraph.hasPrefix("(") else { return nil }
        guard let word = paragraph.split(separator: " ", maxSplits: 1).first else { return nil }
        let name = word.trimmingCharacters(in: CharacterSet(charactersIn: ":："))
        return name.isEmpty ? nil : name
    }

    // 배역 후보: 줄 맨 앞에 2번 이상 나온 짧은 단어 (많이 나온 순)
    static func castCandidates(in text: String) -> [String] {
        var counts: [String: Int] = [:]
        for paragraph in paragraphs(text) where heading(paragraph) == nil {
            guard let word = firstWord(paragraph), word.count <= 6 else { continue }
            counts[word, default: 0] += 1
        }
        return counts
            .filter { $0.value >= 2 }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)
    }

    // 소품 후보에서 아예 뺄 말 (대신 가리키는 말)
    private static let notProps: Set<String> = ["것", "무엇", "그것", "이것", "저것", "누구", "아무것", "모두", "서로"]

    // 소품 후보로 보여 주되 처음엔 체크를 꺼 둘 말 (몸 · 동작에 자주 나오는 말)
    static let bodyWords: Set<String> = [
        "손", "손가락", "고개", "시선", "눈", "눈물", "몸", "발", "팔", "팔뚝", "얼굴", "입", "머리",
        "주먹", "걸음", "숨", "목소리", "자리", "등", "어깨", "허리", "무릎", "다리", "귀", "가슴", "노래", "말",
    ]

    // 처음부터 체크해 둘 소품 후보인지. 몸 · 동작 말과 "노동자들"처럼 사람 여럿을 뜻하는 말은 꺼 둔다
    static func isLikelyProp(_ name: String) -> Bool {
        !bodyWords.contains(name) && !name.hasSuffix("들")
    }

    // 괄호 지문 · 지문 줄에서 "~을/를"로 끝나는 말 = 소품 후보 (많이 나온 순). 배역 이름은 뺀다
    // 예: "(편지를 품에 숨기며 작업대를 탕 치고)" → 편지, 작업대
    static func propCandidates(in text: String, cast: Set<String>) -> [String] {
        var counts: [String: Int] = [:]
        for paragraph in paragraphs(text) where heading(paragraph) == nil {
            let isDialogue = firstWord(paragraph).map(cast.contains) ?? false
            for piece in directions(in: paragraph, isDialogue: isDialogue) {
                for word in piece.split(whereSeparator: { $0.isWhitespace || ",.!?…()".contains($0) }) {
                    guard let last = word.last, last == "을" || last == "를" else { continue }
                    let name = String(word.dropLast())
                    guard (1...6).contains(name.count), !notProps.contains(name), !cast.contains(name) else { continue }
                    counts[name, default: 0] += 1
                }
            }
        }
        return counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)
    }

    // 지문 부분만: 대사 줄이면 괄호 안, 지문 줄이면 줄 전체
    private static func directions(in paragraph: String, isDialogue: Bool) -> [String] {
        guard isDialogue else { return [paragraph] }
        return paragraph.matches(of: /\(([^)]*)\)/).map { String($0.1) }
    }

    // 글 전체 → 장면별 대본. cast = 사용자가 확인한 배역 목록, overrides = 미리보기에서 고친 나누기
    static func parse(_ text: String, cast: Set<String>, overrides: SceneOverrides = SceneOverrides()) -> [ParsedScene] {
        var scenes: [ParsedScene] = []
        var current = ParsedScene()
        var lastNumber: [SceneKind: Int] = [:]   // 직접 나눈 장면 번호 = 같은 종류 바로 앞 번호 + 1

        func startScene(_ scene: ParsedScene) {
            if current.kind != nil || !current.lines.isEmpty { scenes.append(current) }
            current = scene
            if let kind = scene.kind { lastNumber[kind] = scene.number }
        }

        for (index, paragraph) in paragraphs(text).enumerated() {
            if let kind = overrides.splits[index] {
                // 직접 나눈 곳: 이 줄은 새 장면의 첫 줄로 남는다
                startScene(ParsedScene(kind: kind, number: (lastNumber[kind] ?? 0) + 1, splitIndex: index))
            } else if !overrides.merged.contains(index), let heading = heading(paragraph) {
                startScene(ParsedScene(kind: heading.kind, number: heading.number, headingIndex: index))
                // "S15 (장면 설명)"처럼 괄호뿐이면 제목 대신 첫 지문으로
                if heading.rest.hasPrefix("(") {
                    current.lines.append(ParsedLine(index: index, speaker: nil, text: heading.rest))
                } else {
                    current.title = heading.rest
                }
                continue
            }

            if let name = firstWord(paragraph), cast.contains(name) {
                let parts = paragraph.split(separator: " ", maxSplits: 1)
                let line = parts.count > 1 ? String(parts[1]) : ""
                current.lines.append(ParsedLine(index: index, speaker: name, text: line))
            } else {
                current.lines.append(ParsedLine(index: index, speaker: nil, text: paragraph))
            }
        }
        if current.kind != nil || !current.lines.isEmpty { scenes.append(current) }
        return scenes
    }
}
