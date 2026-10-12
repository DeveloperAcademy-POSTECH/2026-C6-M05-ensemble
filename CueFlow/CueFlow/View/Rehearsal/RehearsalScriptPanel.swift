//
//  RehearsalScriptPanel.swift
//  CueFlow
//
//  리허설 모드 왼쪽 대본 패널. 지금 장면의 대본을 보여준다.
//  지문 줄은 회색, 대사 줄은 배역 이름 + 대사 (괄호 지문은 회색 기울임).
//

import SwiftUI

struct RehearsalScriptPanel: View {
    let lines: [ScriptLine]        // 지금 장면의 대본 (순서대로)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(lines) { line in
                    ScriptLineView(speaker: line.speaker, text: line.text)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 96)   // 마지막 줄이 아래 흐림에 가리지 않게
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
