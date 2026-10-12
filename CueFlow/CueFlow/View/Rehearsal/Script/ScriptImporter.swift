//
//  ScriptImporter.swift
//  CueFlow
//
//  나눈 대본을 공연에 넣기 + 파일에서 글자 꺼내기.
//

import Foundation
import AppKit
import PDFKit
import SwiftData
import UniformTypeIdentifiers

enum ScriptImporter {
    // 불러올 수 있는 파일: txt · rtf · docx(워드, 구글 닥스 다운로드) · pdf
    static let fileTypes: [UTType] = [
        .plainText, .rtf, .pdf,
        UTType(filenameExtension: "docx") ?? .data,
    ]

    // 파일 → 글자. 못 읽으면 nil
    static func text(from url: URL) -> String? {
        let canAccess = url.startAccessingSecurityScopedResource()   // 샌드박스: 사용자가 고른 파일 읽기 허락
        defer { if canAccess { url.stopAccessingSecurityScopedResource() } }

        switch url.pathExtension.lowercased() {
        case "pdf":
            return PDFDocument(url: url)?.string
        case "docx":
            return try? NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],
                documentAttributes: nil
            ).string
        case "rtf":
            return try? NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ).string
        default:
            return try? String(contentsOf: url, encoding: .utf8)
        }
    }

    // 대본의 S15가 앱의 몇 번째 장면인지 찾기 (같은 종류끼리 15번째). 없으면 nil
    static func existingScene(for parsed: ParsedScene, in production: Production) -> ShowScene? {
        guard let kind = parsed.kind else { return nil }
        let sameKind = (production.scenes ?? [])
            .filter { $0.kind == kind }
            .sorted { $0.order < $1.order }
        return sameKind.indices.contains(parsed.number - 1) ? sameKind[parsed.number - 1] : nil
    }

    // 나눈 대본을 공연에 넣는다. 그 장면의 원래 대본은 새 대본으로 바뀐다.
    // 앱에 없는 장면(예: 대본엔 S15가 있는데 앱엔 씬이 3개뿐)은 맨 뒤에 새로 만든다.
    // 장면 표시 앞에 있던 글은 currentScene(지금 보고 있는 장면)에 넣는다.
    static func apply(_ parsedScenes: [ParsedScene], to production: Production, currentScene: ShowScene?) {
        var nextOrder = ((production.scenes ?? []).map(\.order).max() ?? -1) + 1

        for parsed in parsedScenes {
            let scene: ShowScene
            if parsed.kind == nil {
                guard let currentScene else { continue }
                scene = currentScene
            } else if let found = existingScene(for: parsed, in: production) {
                scene = found
            } else {
                let title = parsed.title.isEmpty ? parsed.code : parsed.title
                scene = ShowScene(title: title, kind: parsed.kind ?? .scene, order: nextOrder)
                nextOrder += 1
                production.scenes = (production.scenes ?? []) + [scene]
            }

            // 원래 대본 지우고 새로 넣기
            for old in scene.scriptLines ?? [] {
                scene.modelContext?.delete(old)
            }
            scene.scriptLines = parsed.lines.enumerated().map { index, line in
                ScriptLine(order: index, speaker: line.speaker, text: line.text)
            }
        }
    }
}
