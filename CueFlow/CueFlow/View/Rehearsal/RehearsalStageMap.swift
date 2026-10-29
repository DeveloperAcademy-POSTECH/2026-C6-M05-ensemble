//
//  RehearsalStageMap.swift
//  CueFlow
//
//  리허설 모드 무대 미니맵 카드 (피그마 리허설모드_ver1).
//  지금 장면의 무대 배치를 보여준다. 장면을 고친 적 없으면 최초 상태 배치.
//  큐를 넘기면 그 큐까지 적용해서 배역 · 소품이 옮겨진다 (StageCueMoves). 지금 큐가 옮긴 것은 둘레가 빛난다.
//  최초 상태 배치가 없으면 "첫 무대 배치를 시작해보세요" (피그마 리허설모드_무대배치01).
//

import SwiftUI

struct RehearsalStageMap: View {
    let production: Production
    let scene: ShowScene?          // 지금 장면
    let triggers: [Trigger]        // 지금 장면의 트리거 (순서대로)
    let currentTriggerIndex: Int   // 지금 큐

    private enum Editing: Identifiable {
        case firstSetup             // 배치하기 → 배우 · 소품 목록부터
        case scene(ShowScene)       // 수정하기 → 이 장면 배치

        var id: String {
            switch self {
            case .firstSetup: "first"
            case .scene(let scene): scene.id.uuidString
            }
        }
    }
    @State private var editing: Editing?

    // 장면 배치 + 지금 큐까지 옮긴 것
    private var marks: [StageMark] {
        StageCueMoves.marks(
            start: production.stagePlacements(for: scene).map(\.mark),
            triggers: triggers,
            through: currentTriggerIndex,
            production: production
        )
    }

    // 지금 큐가 옮긴 배역 · 소품
    private var movingIDs: Set<String> {
        guard triggers.indices.contains(currentTriggerIndex) else { return [] }
        let cues = triggers[currentTriggerIndex].cues ?? []
        return Set(cues.flatMap { cue in
            StageArea(cue.position) == nil ? [] :
                StageCueMoves.movedNames(by: cue, production: production).map { "\($0.1.rawValue)-\($0.0)" }
        })
    }

    private var hasInitialPlacements: Bool {
        !(production.initialPlacements ?? []).isEmpty
    }

    var body: some View {
        RehearsalCard {
            if hasInitialPlacements {
                minimapView
            } else {
                emptyView
            }
        }
        .sheet(item: $editing) { editing in
            switch editing {
            case .firstSetup: StageSetupSheet(production: production)
            case .scene(let scene): StageSetupSheet(production: production, scene: scene)
            }
        }
    }

    // "무대 미니맵" + 수정하기 / 미니맵
    private var minimapView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("무대 미니맵")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.neutral900)
                Spacer()
                Button {
                    if let scene { editing = .scene(scene) }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16))
                        Text("수정하기")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Color.neutral900)
                    .padding(.horizontal, 8)
                    .frame(height: 36)
                    .background(Color.neutral25, in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.neutral300, lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(scene == nil)
            }
            .padding(.leading, 33)
            .padding(.trailing, 14)
            .frame(height: 58)

            Divider()

            StageMinimap(marks: marks, highlightedIDs: movingIDs)
                .padding(.leading, 31)
                .padding(.trailing, 28)
                .padding(.top, 18)   // 카드 높이 378 안에 범례까지 들어가게 (피그마 18)
        }
    }

    // 최초 상태 배치가 없을 때 (피그마 리허설모드_무대배치01)
    private var emptyView: some View {
        VStack(spacing: 10) {
            Text("첫 무대 배치를 시작해보세요")
                .font(.system(size: 20, weight: .semibold))
                .tracking(-0.45)
                .foregroundStyle(Color.neutral900)
            Text("배우와 소품을 추가하고 무대 위 원하는 위치에 배치해보세요.\n첫 무대 배치 이후 장면별 무대 구성을 한눈에 확인할 수 있어요.")
                .font(.system(size: 17))
                .lineSpacing(4)
                .foregroundStyle(Color.neutral700)
                .multilineTextAlignment(.center)
            Button {
                editing = .firstSetup
            } label: {
                Text("배치하기")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.brandPrimaryText)
                    .frame(width: 104, height: 35)
                    .background(Color.brandPrimarySubtle, in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("미니맵") {
    let production = RehearsalPreviewData.production
    let scene = production.scenes?.first
    let triggers = (scene?.triggers ?? []).sorted { $0.order < $1.order }
    RehearsalStageMap(production: production, scene: scene, triggers: triggers, currentTriggerIndex: 2)
        .frame(width: 1009, height: 384)
        .padding()
}

#Preview("빈 화면") {
    let production = RehearsalPreviewData.production
    production.initialPlacements = []
    return RehearsalStageMap(production: production, scene: production.scenes?.first, triggers: [], currentTriggerIndex: 0)
        .frame(width: 1009, height: 378)
        .padding()
}
