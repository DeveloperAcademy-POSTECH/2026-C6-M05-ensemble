
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
        RehearsalCard(title: "대본", cornerRadius: 10) {
            if lines.isEmpty {
                emptyView
            } else {
                scriptView
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onEdit) {
                HStack(spacing: 8) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 14, weight: .semibold))
                    Text("대본 입력")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
                .buttonStyle(.plain)
                .foregroundStyle(Color.brandPrimaryText)
                .padding(.trailing, 22)
            .frame(height: 54)
        }
        // 피그마: 아래로 퍼지는 아주 옅은 그림자 두 겹
        .shadow(color: .black.opacity(0.04), radius: 12, y: 8)
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
    }

    private var scriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(lines) { line in
                        lineRow(line, isHighlighted: line.id == highlightedLineID)
                            .id(line.id)
                    }
                }
                .padding(.top, 11)
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

    // 대본 한 줄. 하이라이트면 카드 폭 끝까지 연보라 바탕 + 왼쪽 가장자리 보라 막대 (큐 목록의 지금 큐 줄과 같은 모양)
    private func lineRow(_ line: ScriptLine, isHighlighted: Bool) -> some View {
        ScriptLineView(speaker: line.speaker, text: line.text)
            .padding(.leading, 22)
            .padding(.trailing, 36)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHighlighted ? Color.brandPrimarySubtle.opacity(0.4) : Color.clear)
            .overlay(alignment: .leading) {
                if isHighlighted {
                    Rectangle()
                        .fill(Color.brandPrimaryHover)
                        .frame(width: 4)
                }
            }
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Text("이 장면의 대본이 없어요")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.neutral900)
            Text("구글 닥스에서 복사해 붙여넣거나\n파일을 불러올 수 있어요")
                .font(.body)
                .lineSpacing(2)
                .foregroundStyle(Color.neutral600)
                .multilineTextAlignment(.center)
            Button(action: onEdit) {
                Label("대본 가져오기", systemImage: "square.and.arrow.up")
                    .font(.body.weight(.regular))
            }
            .buttonStyle(.primary)
            .frame(width: 120, height: 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 대본 한 줄 모양 (대본 패널 · 대본 입력 미리보기 공용)
struct ScriptLineView: View {
    let speaker: String?
    let text: String
    var fontSize: CGFloat = 15   // 대본 입력 미리보기는 17

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let speaker {
                Text(speaker)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.neutral800)
            }

            Text(ScriptLineView.styled(text, isDirection: speaker == nil, fontSize: fontSize))
                .foregroundStyle(Color.neutral800)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // 괄호 (지문) 부분만 회색. 지문 줄이면 전부 보통 굵기
    // 피그마: 대사는 굵게(bold), 괄호 지문은 보통 굵기 회색, 지문 줄은 보통 굵기 진한 색
    static func styled(_ text: String, isDirection: Bool, fontSize: CGFloat = 15) -> AttributedString {
        var result = AttributedString()
        var depth = 0          // 괄호 안에 있는지
        var piece = ""

        func flush() {
            guard !piece.isEmpty else { return }
            var run = AttributedString(piece)
            if isDirection {
                run.font = .system(size: fontSize)
                run.foregroundColor = Color.neutral900
            } else if depth > 0 {
                run.font = .system(size: fontSize)
                run.foregroundColor = Color.neutral600
            } else {
                run.font = .system(size: fontSize, weight: .bold)
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
