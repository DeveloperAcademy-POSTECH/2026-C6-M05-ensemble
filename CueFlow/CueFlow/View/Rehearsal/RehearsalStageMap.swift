//
//  RehearsalStageMap.swift
//  CueFlow
//
//  리허설 모드 무대 배치도. 상수 | 무대(3×3 칸) | 하수 에 지금 장면의 큐를 위치대로 보여준다.
//  무대 큐는 아래 "칸 미정"에서 무대 칸으로 끌어다 놓아 자리를 정한다 (Cue.stageCell).
//  TODO: 점 옆 글자 — 지금은 큐 제목. 피그마처럼 짧은 이름(판틴, 물레)이 필요한지 팀 확인
//

import SwiftUI

struct RehearsalStageMap: View {
    let cues: [Cue]   // 지금 장면의 큐 (트리거 순서대로)

    private func cues(at position: CuePosition) -> [Cue] {
        cues.filter { $0.position == position }
    }

    // 무대 큐 중 칸을 아직 안 정한 것
    private var unplacedStageCues: [Cue] {
        cues(at: .stage).filter { $0.stageCell == nil }
    }

    var body: some View {
        RehearsalCard {
            VStack(spacing: 16) {
                HStack(spacing: 23) {
                    sideZone(.sangsu)
                        .frame(width: 166)

                    stageGrid

                    sideZone(.hasu)
                        .frame(width: 166)
                }

                unplacedRow
            }
            .padding(.horizontal, 31)
            .padding(.vertical, 22)
        }
    }

    // 상수 / 하수: 칸 없이 큐를 위에서부터 나열
    private func sideZone(_ position: CuePosition) -> some View {
        VStack(spacing: 8) {
            zoneLabel(position.rawValue)
            ForEach(cues(at: position)) { cue in
                CueStageChip(cue: cue)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // 큐가 없어도 구역 크기 그대로
        .zoneBox()
    }

    // 무대: 3×3 칸
    private var stageGrid: some View {
        VStack(spacing: 6) {
            zoneLabel("무대")

            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        ForEach(0..<3, id: \.self) { column in
                            StageCellView(
                                index: row * 3 + column,
                                cues: cues(at: .stage).filter { $0.stageCell == row * 3 + column },
                                allCues: cues
                            )
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity)
        .zoneBox()
    }

    // 칸을 아직 안 정한 무대 큐. 여기로 끌어다 놓으면 칸이 비워진다.
    private var unplacedRow: some View {
        HStack(spacing: 8) {
            Text("칸 미정")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if unplacedStageCues.isEmpty {
                Text("무대 큐를 모두 배치했어요")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ForEach(unplacedStageCues) { cue in
                CueStageChip(cue: cue)
                    .fixedSize()
            }

            Spacer(minLength: 0)
        }
        .frame(height: 28)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { ids, _ in
            Cue.find(ids, in: cues).forEach { $0.stageCell = nil }
            return true
        }
    }

    private func zoneLabel(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }
}

// 무대 3×3 중 한 칸. 큐를 끌어다 놓으면 이 칸으로 정해진다.
struct StageCellView: View {
    let index: Int
    let cues: [Cue]      // 이 칸에 있는 큐
    let allCues: [Cue]   // 끌어온 큐를 찾기 위한 지금 장면 전체 큐

    @State private var isTargeted = false   // 큐를 끌고 이 칸 위에 올라와 있는지

    var body: some View {
        VStack(spacing: 4) {
            ForEach(cues) { cue in
                CueStageChip(cue: cue)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            isTargeted ? Color.brandPrimarySubtle : Color.clear,
            in: RoundedRectangle(cornerRadius: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.brandPrimaryDisabled, style: StrokeStyle(lineWidth: 1, dash: [3]))
        }
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { ids, _ in
            Cue.find(ids, in: allCues).forEach { $0.stageCell = index }
            return true
        } isTargeted: {
            isTargeted = $0
        }
    }
}

// 배치도 위 큐 하나: "● 공장 전체조명 ON" (점 = 파트 색). 무대 큐는 끌어서 옮길 수 있다.
struct CueStageChip: View {
    let cue: Cue

    var body: some View {
        let chip = HStack(spacing: 5) {
            Circle()
                .fill(cue.part?.color.accent ?? Color.brandPrimaryHover)
                .frame(width: 7, height: 7)
            Text(cue.title)
                .font(.system(size: 10))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())   // 글자 사이 빈 곳을 잡아도 끌리게
        .help(cue.title)

        if cue.position == .stage {
            chip.draggable(cue.id.uuidString)   // 끌 때 큐 id를 글자로 넘긴다
        } else {
            chip
        }
    }
}

extension Cue {
    // 끌어다 놓은 id 글자들로 큐 찾기
    static func find(_ ids: [String], in cues: [Cue]) -> [Cue] {
        cues.filter { ids.contains($0.id.uuidString) }
    }
}

private extension View {
    // 상수 · 무대 · 하수 구역 네모
    func zoneBox() -> some View {
        self
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.brandPrimaryDisabled, lineWidth: 1)
            }
    }
}

#Preview {
    RehearsalStageMap(cues: RehearsalPreviewData.sceneCues)
        .frame(width: 1009, height: 378)
        .padding()
}
