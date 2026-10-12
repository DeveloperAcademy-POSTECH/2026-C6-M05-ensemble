//
//  RehearsalScriptPanel.swift
//  CueFlow
//
//  리허설 모드 왼쪽 대본 패널. 지문 / 인물 이름 + (행동 지시) 대사.
//  TODO: 대본은 아직 모델에 없음 → 저장 방식 팀과 정한 뒤 장면별 대본 연결. 지금은 예시 대본만 보여준다.
//

import SwiftUI

// 대본 한 줄
struct ScriptLine: Identifiable {
    let id = UUID()
    var speaker: String?        // 인물 이름. 없으면 지문만 있는 줄 (예: "하루가 끝날 무렵, 공장 안…")
    var direction: String?      // 괄호 안 행동 지시 (예: "편지를 품에 급히 숨기며 작게")
    var text: String            // 대사 (지문 줄이면 지문)
    var isHighlighted = false   // 보라색 이름 (피그마의 판틴). TODO: 무슨 뜻인지 디자이너 확인 (내 배역? 지금 큐와 연결된 줄?)
}

struct RehearsalScriptPanel: View {
    let lines: [ScriptLine]

    var body: some View {
        RehearsalCard(title: "대본") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(lines) { line in
                        ScriptLineView(line: line)
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
    }
}

struct ScriptLineView: View {
    let line: ScriptLine

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let speaker = line.speaker {
                Text(speaker)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(line.isHighlighted ? Color.brandPrimary : Color.secondary)
            }

            dialogue
                .font(.system(size: 15))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // "(행동 지시) 대사" — 행동 지시는 회색 기울임, 지문 줄은 전부 회색
    private var dialogue: Text {
        if line.speaker == nil {
            return Text(line.text).foregroundStyle(.secondary)
        }
        guard let direction = line.direction else {
            return Text(line.text)
        }
        return Text("(\(direction)) ").italic().foregroundStyle(.secondary) + Text(line.text)
    }
}

#Preview {
    RehearsalScriptPanel(lines: RehearsalPreviewData.scriptLines)
        .frame(width: 360, height: 772)
        .padding()
}
