
//
//  RehearsalScriptPanel.swift
//  CueFlow
//
//  리허설 모드 왼쪽 대본 패널. 지금 장면의 대본을 보여준다.
//  지문 줄은 회색, 대사 줄은 배역 이름 + 대사 (괄호 지문은 회색 기울임).
//  지금 큐에 해당하는 줄(ScriptCueMatcher가 찾은 줄)은 연보라 + 왼쪽 막대로 하이라이트하고 그 줄로 스크롤한다.
//

import SwiftUI

struct RehearsalScriptPanel: View {
    let lines: [ScriptLine]        // 지금 장면의 대본 (순서대로)
    var highlightedLineID: UUID?   // 지금 큐에 해당하는 줄
    let onEdit: () -> Void         // "대본 입력" 창 열기

    var body: some View {
        RehearsalCard(title: "대본") {
            if lines.isEmpty {
                emptyView
            } else {
                scriptView
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onEdit) {
                Label("대본 입력", systemImage: "square.and.pencil")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.brandPrimaryText)
            .padding(.trailing, 18)
            .frame(height: 54)
        }
    }

    private var scriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(lines) { line in
                        lineRow(line, isHighlighted: line.id == highlightedLineID)
                            .id(line.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 96)   // 마지막 줄이 아래 흐림에 가리지 않게
            }
            // 큐를 넘기면 그 줄로 스크롤
            .onChange(of: highlightedLineID, initial: true) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
        // 아래쪽이 흐려지며 사라지는 효과 (피그마 Fade)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [Color(nsColor: .textBackgroundColor).opacity(0), Color(nsColor: .textBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 96)
            .allowsHitTesting(false)
        }
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 12, bottomTrailingRadius: 12))
    }

    // 대본 한 줄. 하이라이트면 연보라 바탕 + 왼쪽 보라 막대 (큐 목록의 지금 큐 줄과 같은 모양)
    private func lineRow(_ line: ScriptLine, isHighlighted: Bool) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isHighlighted ? Color.brandPrimary : Color.clear)
                .frame(width: 4)
            ScriptLineView(speaker: line.speaker, text: line.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(isHighlighted ? Color.brandPrimarySubtle : Color.clear, in: RoundedRectangle(cornerRadius: 6))
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Text("이 장면의 대본이 없어요")
                .font(.callout.weight(.semibold))
            Text("구글 닥스에서 복사해 붙여넣거나\n파일을 불러올 수 있어요")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("대본 입력", action: onEdit)
                .buttonStyle(.primary)
                .frame(width: 120, height: 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 대본 한 줄 모양 (대본 패널 · 대본 입력 미리보기 공용)
struct ScriptLineView: View {
    let speaker: String?
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let speaker {
                Text(speaker)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(ScriptLineView.styled(text, isDirection: speaker == nil))
                .font(.system(size: 15))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // 괄호 (지문) 부분만 회색 기울임. 지문 줄이면 전부 회색
    static func styled(_ text: String, isDirection: Bool) -> AttributedString {
        var result = AttributedString()
        var depth = 0          // 괄호 안에 있는지
        var piece = ""

        func flush() {
            guard !piece.isEmpty else { return }
            var run = AttributedString(piece)
            if isDirection || depth > 0 {
                run.foregroundColor = .secondary
            }
            if depth > 0 {
                run.inlinePresentationIntent = .emphasized
            }
            result += run
            piece = ""
        }

        for character in text {
            if character == "(" {
                flush()
                depth += 1
                piece.append(character)
            } else if character == ")" {
                piece.append(character)
                flush()
                depth = max(depth - 1, 0)
            } else {
                piece.append(character)
            }
        }
        flush()
        return result
    }
}

#Preview {
    RehearsalScriptPanel(lines: RehearsalPreviewData.scriptLines) { }
        .frame(width: 360, height: 772)
        .padding()
}
