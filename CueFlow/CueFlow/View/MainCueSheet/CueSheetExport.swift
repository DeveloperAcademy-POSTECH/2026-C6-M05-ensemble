//
//  CueSheetExport.swift
//  CueFlow
//
//  큐시트 내보내기: 줄 목록을 CSV(엑셀) · PDF 파일 내용으로 바꾼다.
//  어떤 줄을 어떤 순서로 내보낼지는 Production+CueSheetExport.swift에서 정한다.
//

import AppKit
import SwiftUI

// 내보낼 큐 한 줄
struct CueSheetRow {
    let sceneCode: String    // S#1 · N#1 · 암전
    let sceneTitle: String
    let number: String       // 01, 02 … 번호 없는 큐는 00
    let part: String
    let trigger: String
    let title: String
    let position: String     // 상수 · 하수 · 콘솔 · 무대 · 무대 3
}

enum CueSheetExport {
    // 엑셀에서 한글이 깨지지 않게 UTF-8 BOM을 붙이고, 줄바꿈은 CRLF
    static func csv(rows: [CueSheetRow]) -> Data {
        let header = ["씬", "장면 이름", "번호", "파트", "트리거", "큐 내용", "위치"]
        let lines = [header] + rows.map {
            [$0.sceneCode, $0.sceneTitle, $0.number, $0.part, $0.trigger, $0.title, $0.position]
        }
        let text = lines.map { $0.map { csvCell($0) }.joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
        return Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
    }

    private static func csvCell(_ text: String) -> String {
        // =, +, -, @로 시작하면 엑셀이 수식으로 실행할 수 있어서 글자로 막는다
        let safe = ["=", "+", "-", "@", "\t", "\r"].contains { text.hasPrefix($0) } ? "'" + text : text
        guard safe.contains(where: { ",\"\r\n".contains($0) }) else { return safe }
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // A4 가로. 장면이 바뀔 때마다 장면 제목 줄, 페이지마다 표 머리글
    @MainActor
    static func pdf(title: String, rows: [CueSheetRow]) -> Data? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: PDFLayout.pageWidth, height: PDFLayout.pageHeight)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        let writer = CueSheetPDFWriter(context: context)
        writer.startPage()
        writer.draw(Text(title).font(.system(size: 18, weight: .bold)).padding(.bottom, 10))
        writer.draw(CueSheetPDFHeader())

        var currentScene: String?
        for row in rows {
            let scene = "\(row.sceneCode) \(row.sceneTitle)"
            if scene != currentScene {
                currentScene = scene
                writer.keepRoom(60)   // 장면 제목만 페이지 끝에 혼자 남지 않게
                writer.draw(CueSheetPDFSceneTitle(text: scene))
            }
            writer.draw(CueSheetPDFRow(row: row))
        }
        writer.finish()
        return data as Data
    }
}

private enum PDFLayout {
    static let pageWidth: CGFloat = 842
    static let pageHeight: CGFloat = 595
    static let margin: CGFloat = 36
    static var contentWidth: CGFloat { pageWidth - margin * 2 }
    // 번호 · 파트 · 트리거 · 큐 내용 · 위치 (합 = contentWidth)
    static let columns: [CGFloat] = [44, 86, 270, 290, 80]
}

// 위에서 아래로 뷰를 그려 나가다가 칸이 모자라면 다음 페이지로 넘긴다
@MainActor
private final class CueSheetPDFWriter {
    private let context: CGContext
    private var y: CGFloat = 0
    private var pageNumber = 0

    init(context: CGContext) {
        self.context = context
    }

    func startPage() {
        context.beginPDFPage(nil)
        pageNumber += 1
        y = PDFLayout.margin
        place(Text("\(pageNumber)").font(.system(size: 9)).foregroundStyle(.gray)
            .frame(maxWidth: .infinity, alignment: .trailing),
              atBottom: PDFLayout.pageHeight - 22)
    }

    func draw(_ view: some View) {
        render(view) { size, drawContent in
            if y + size.height > PDFLayout.pageHeight - PDFLayout.margin {
                endPage()
                startPage()
                drawRepeatedHeader()
            }
            drawAt(top: y, size: size, drawContent)
            y += size.height
        }
    }

    func keepRoom(_ height: CGFloat) {
        guard y + height > PDFLayout.pageHeight - PDFLayout.margin else { return }
        endPage()
        startPage()
        drawRepeatedHeader()
    }

    func finish() {
        endPage()
        context.closePDF()
    }

    private func endPage() {
        context.endPDFPage()
    }

    private func drawRepeatedHeader() {
        render(CueSheetPDFHeader()) { size, drawContent in
            drawAt(top: y, size: size, drawContent)
            y += size.height
        }
    }

    private func place(_ view: some View, atBottom bottom: CGFloat) {
        render(view) { size, drawContent in
            drawAt(top: bottom - size.height, size: size, drawContent)
        }
    }

    private func render(_ view: some View, _ body: (CGSize, (CGContext) -> Void) -> Void) {
        let renderer = ImageRenderer(content: view
            .frame(width: PDFLayout.contentWidth, alignment: .leading)
            .environment(\.colorScheme, .light))   // 다크 모드에서 내보내도 흰 종이에 검은 글자
        renderer.proposedSize = ProposedViewSize(width: PDFLayout.contentWidth, height: nil)
        renderer.render(renderer: body)
    }

    private func drawAt(top: CGFloat, size: CGSize, _ drawContent: (CGContext) -> Void) {
        context.saveGState()
        // PDF는 아래쪽이 0이라 위에서부터 잰 값을 뒤집는다
        context.translateBy(x: PDFLayout.margin, y: PDFLayout.pageHeight - top - size.height)
        drawContent(context)
        context.restoreGState()
    }
}

private struct CueSheetPDFHeader: View {
    var body: some View {
        CueSheetPDFColumns(values: ["번호", "파트", "트리거", "큐 내용", "위치"])
            .font(.system(size: 10, weight: .semibold))
            .background(Color(white: 0.92))
    }
}

private struct CueSheetPDFSceneTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .padding(.top, 12)
            .padding(.bottom, 5)
    }
}

private struct CueSheetPDFRow: View {
    let row: CueSheetRow

    var body: some View {
        CueSheetPDFColumns(values: [row.number, row.part, row.trigger, row.title, row.position])
            .font(.system(size: 10))
            .overlay(alignment: .bottom) { Color(white: 0.8).frame(height: 0.5) }
    }
}

private struct CueSheetPDFColumns: View {
    let values: [String]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(zip(values, PDFLayout.columns).enumerated()), id: \.offset) { _, column in
                Text(column.0)
                    .fixedSize(horizontal: false, vertical: true)   // 길면 다음 줄로
                    .padding(.horizontal, 5)
                    .padding(.vertical, 5)
                    .frame(width: column.1, alignment: .leading)
            }
        }
        .foregroundStyle(.black)
    }
}
