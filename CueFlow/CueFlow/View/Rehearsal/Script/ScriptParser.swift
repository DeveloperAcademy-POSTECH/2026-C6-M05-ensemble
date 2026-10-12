//
//  ScriptParser.swift
//  CueFlow
//
//  붙여넣은 대본 글을 장면 / 배역 / 대사 / 지문으로 나누는 규칙.
//  - 줄 맨 앞 S15 · N10 · D3 (S#15도 됨) → 새 장면 시작 (씬 · 넘버 · 전환)
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
    var lines: [ParsedLine] = []

    var code: String {
        guard let kind else { return "" }
        return "\(kind.codePrefix)#\(number)"
    }
}

// 나눈 결과: 대본 한 줄
struct ParsedLine: Identifiable {
    let id = UUID()
    var speaker: String?   // nil = 지문
    var text: String
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

    // "S15 장면 설명" → (씬, 15, "장면 설명"). 장면 표시가 아니면 nil
    static func heading(_ paragraph: String) -> (kind: SceneKind, number: Int, rest: String)? {
        guard let match = paragraph.wholeMatch(of: /([SND])\s?#?\s?(\d+)(\s+.*)?/),
              let number = Int(match.2) else { return nil }

        let kind: SceneKind = switch match.1 {
        case "N": .number
        case "D": .transition
        default: .scene
        }
        let rest = (match.3.map(String.init) ?? "").trimmingCharacters(in: .whitespaces)
        return (kind, number, rest)
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

    // 글 전체 → 장면별 대본. cast = 사용자가 확인한 배역 목록
    static func parse(_ text: String, cast: Set<String>) -> [ParsedScene] {
        var scenes: [ParsedScene] = []
        var current = ParsedScene()

        for paragraph in paragraphs(text) {
            if let heading = heading(paragraph) {
                if current.kind != nil || !current.lines.isEmpty { scenes.append(current) }
                current = ParsedScene(kind: heading.kind, number: heading.number)
                // "S15 (장면 설명)"처럼 괄호뿐이면 제목 대신 첫 지문으로
                if heading.rest.hasPrefix("(") {
                    current.lines.append(ParsedLine(speaker: nil, text: heading.rest))
                } else {
                    current.title = heading.rest
                }
                continue
            }

            if let name = firstWord(paragraph), cast.contains(name) {
                let parts = paragraph.split(separator: " ", maxSplits: 1)
                let line = parts.count > 1 ? String(parts[1]) : ""
                current.lines.append(ParsedLine(speaker: name, text: line))
            } else {
                current.lines.append(ParsedLine(speaker: nil, text: paragraph))
            }
        }
        if current.kind != nil || !current.lines.isEmpty { scenes.append(current) }
        return scenes
    }
}
