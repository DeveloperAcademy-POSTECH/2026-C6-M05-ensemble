//
//  ScriptPropAI.swift
//  CueFlow
//
//  Apple Intelligence(Foundation Models)로 지문에서 소품 후보 찾기.
//  규칙("~을/를")이 놓치는 "칼로 찌른다", "의자에 앉는다" 같은 것도 잡아 보려고.
//  - 맥에서 Apple Intelligence를 못 쓰면(꺼짐 · 인텔 맥 · 한국어 미지원) 아무것도 안 한다 → 규칙 결과만 남음
//  - 한 번에 읽을 수 있는 양이 적어서 지문을 조각내서 묻는다
//  - AI가 지어낸 이름은 버린다 (대본에 그 글자가 실제로 있어야 후보)
//  - 안전 필터: 기본 모드는 "칼로 밧줄을 끊고", "머리를 툭 친다" 같은 지문을 위험하다며 거부한다 (11/9 시험: 지문 전체가 0개).
//    덜 엄격한 모드(permissiveContentTransformations)는 글로 답받을 때만 통해서, 구조체(@Generable) 대신 "쉼표로 나열" 글을 받아 나눈다
//

import Foundation
import FoundationModels
import os

enum ScriptPropAI {
    private static let logger = Logger(subsystem: "Happymondayy.CueFlow", category: "ScriptPropAI")

    // 한 번에 보낼 지문 글자 수. 모델이 읽을 수 있는 양(약 4천 토큰)보다 넉넉히 작게
    private static let chunkLimit = 1200

    // 이 맥에서 쓸 수 있는지
    static var isAvailable: Bool { unavailableReason == nil }

    // 못 쓰는 이유 (쓸 수 있으면 nil) — 화면에 보여 줘서 왜 안 도는지 알 수 있게
    static var unavailableReason: String? {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale(Locale(identifier: "ko_KR")) ? nil : "한국어를 지원하지 않아요"
        case .unavailable(.deviceNotEligible):
            return "이 맥은 Apple Intelligence를 지원하지 않아요"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "시스템 설정에서 Apple Intelligence가 꺼져 있어요"
        case .unavailable(.modelNotReady):
            return "Apple Intelligence 모델을 아직 내려받는 중이에요"
        case .unavailable:
            return "Apple Intelligence를 쓸 수 없어요"
        }
    }

    // 공연 대본엔 싸움 · 죽음 장면이 흔해서 덜 엄격한 안전 필터를 쓴다
    private static let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)

    private static let instructions = """
        너는 연극·뮤지컬 무대 감독을 돕는다. 대본 지문을 읽고 무대 소품만 골라낸다.
        소품 = 배우가 손에 들거나 옮기거나 쓰는 물건, 또는 무대에 놓이는 가구·장치 (예: 편지, 칼, 의자, 작업대, 촛대).
        사람, 배역 이름, 몸(손·고개·눈물), 감정, 소리, 조명, 장소는 소품이 아니다.
        지문에 실제로 나온 단어만 쓰고, 조사는 뗀다 (칼로 → 칼).
        답은 소품 이름만 쉼표로 나열한다. 설명은 쓰지 않는다. 소품이 없으면 "없음"이라고만 쓴다.
        """

    // 지문을 조각내서 묻고, 조각마다 새로 찾은 소품을 onFound로 알린다. 새로 찾은 개수를 돌려준다
    // cast = 배역 이름 (소품에서 뺀다), known = 이미 후보에 있는 것 (다시 알리지 않는다)
    @discardableResult
    static func findProps(
        in text: String,
        cast: Set<String>,
        known: Set<String>,
        onFound: @MainActor ([String]) -> Void
    ) async -> Int {
        if let unavailableReason {
            logger.notice("Apple Intelligence 못 씀(\(unavailableReason)) → 규칙 결과만")
            return 0
        }
        var seen = known
        let started = Date.now

        for chunk in chunks(ScriptParser.stageDirections(in: text, cast: cast)) {
            if Task.isCancelled { return seen.count - known.count }
            // 조각마다 새 대화 (앞 조각 내용이 쌓여서 읽을 양을 넘지 않게)
            let session = LanguageModelSession(model: model, instructions: instructions)
            do {
                let answer = try await session.respond(to: "다음 지문에서 소품을 골라줘.\n\n\(chunk)")
                let found = names(in: answer.content)
                    .filter { name in
                        (1...10).contains(name.count) && !cast.contains(name) && chunk.contains(name)
                    }
                var fresh: [String] = []
                for name in found where !seen.contains(name) {
                    seen.insert(name)
                    fresh.append(name)
                }
                if !fresh.isEmpty { onFound(fresh) }
            } catch {
                // 한 조각이 실패해도(안전 필터 · 너무 김 등) 나머지는 계속
                logger.error("소품 찾기 실패: \(error)")
            }
        }
        logger.notice("AI 소품 찾기 끝: 새로 \(seen.count - known.count)개, \(Date.now.timeIntervalSince(started), format: .fixed(precision: 1))초")
        return seen.count - known.count
    }

    // "편지, 칼, 의자" · "- 편지\n- 칼" 같은 답 → ["편지", "칼", "의자"]
    private static func names(in answer: String) -> [String] {
        answer
            .split(whereSeparator: { ",，、\n".contains($0) })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " -•*.·\"'").union(.whitespacesAndNewlines)) }
            .filter { !$0.isEmpty && $0 != "없음" }
    }

    // 지문 줄들을 chunkLimit 글자 이하 묶음으로
    private static func chunks(_ pieces: [String]) -> [String] {
        var result: [String] = []
        var current = ""
        for piece in pieces {
            if !current.isEmpty, current.count + piece.count > chunkLimit {
                result.append(current)
                current = ""
            }
            current += (current.isEmpty ? "" : "\n") + String(piece.prefix(chunkLimit))
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
