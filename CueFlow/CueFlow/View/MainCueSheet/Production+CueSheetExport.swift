//
//  Production+CueSheetExport.swift
//  CueFlow
//
//  큐시트 내보내기: 공연 데이터를 줄로 펴고, 저장 창을 띄워 파일로 저장한다.
//

import AppKit
import SwiftData
import UniformTypeIdentifiers

enum CueSheetExportFormat {
    case csv, pdf

    var fileExtension: String { self == .csv ? "csv" : "pdf" }
    var contentType: UTType { self == .csv ? .commaSeparatedText : .pdf }
}

extension Production {
    // 공연 흐름 순서 → 장면 안에서는 리허설과 같은 순서 (번호 순, 번호 없는 큐는 트리거 순으로 뒤에)
    var cueSheetRows: [CueSheetRow] {
        let scenes = (self.scenes ?? []).sorted { $0.order < $1.order }
        return scenes.flatMap { scene in
            let triggers = (scene.triggers ?? []).sorted { $0.order < $1.order }
            let cues = triggers.flatMap { trigger in
                (trigger.cues ?? []).sorted { $0.createdAt < $1.createdAt }
            }
            let numbered = cues.filter { $0.order > 0 }.sorted { $0.order < $1.order }
            let unnumbered = cues.filter { $0.order == 0 }
            return (numbered + unnumbered).map { cue in
                CueSheetRow(
                    sceneCode: scene.code(in: scenes),
                    sceneTitle: scene.title,
                    number: String(format: "%02d", cue.order),
                    part: cue.part?.name ?? "",
                    trigger: cue.trigger?.text ?? "",
                    title: cue.title,
                    position: cue.exportPosition
                )
            }
        }
    }

    // 저장 창 → 고른 곳에 파일 저장. 취소하면 아무것도 안 함
    @MainActor
    func exportCueSheet(as format: CueSheetExportFormat) {
        let panel = NSSavePanel()
        panel.title = "큐시트 내보내기"
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true
        let name = title.replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "\(name) 큐시트.\(format.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let rows = cueSheetRows
        let data = format == .csv ? CueSheetExport.csv(rows: rows) : CueSheetExport.pdf(title: title, rows: rows)
        do {
            guard let data else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: url, options: .atomic)
        } catch {
            let alert = NSAlert()
            alert.messageText = "내보내지 못했어요"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

private extension Cue {
    var exportPosition: String {
        guard position == .stage, let stageCell else { return position.rawValue }
        return "무대 \(stageCell + 1)"
    }
}
