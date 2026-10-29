//
//  StageSetupSheet.swift
//  CueFlow
//
//  무대 배치 창.
//  처음("배치하기"): 배우 · 소품 목록 → 다음으로 → 최초 상태 무대 배치 → 배치 완료
//  장면에서("수정하기"): 배우 · 소품 목록(이름 고치기) → 다음으로 → 그 장면의 무대 배치
//  위쪽 이름 카드를 눌러 고른 뒤 놓을 무대 칸을 누른다 (피그마 1354:7896 — 끌기는 불편하다는 의견으로 바꿈).
//  놓인 점도 눌러서 고른 뒤 다른 칸을 누르면 옮겨진다. 빼기는 점 우클릭 또는 미니맵 밖으로 끌기.
//  배치 완료를 눌러야 저장된다.
//

import SwiftUI
import SwiftData

struct StageSetupSheet: View {
    let production: Production
    let scene: ShowScene?          // nil = 최초 상태 배치, 있으면 그 장면의 배치

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private enum Step { case names, placement }
    @State private var step: Step = .names

    init(production: Production, scene: ShowScene? = nil) {
        self.production = production
        self.scene = scene
    }

    var body: some View {
        switch step {
        case .names:
            CastPropListSheet(production: production, onBack: { dismiss() }) {
                step = .placement
            }
        case .placement:
            StagePlacementEditor(
                title: scene == nil ? "최초 무대 상태 배치" : "\(sceneName) 무대 배치",
                subtitle: scene == nil
                    ? "공연 시작 전, 배역과 소품의 위치를 정해주세요. 이 위치를 기준으로 장면별 이동 동선이 이어집니다.\n배역이나 소품 카드를 선택한 뒤, 놓을 해당 무대 칸을 클릭해주세요."
                    : "이 장면에서 배역과 소품이 있는 자리로 옮겨주세요.\n배역이나 소품 카드를 선택한 뒤, 놓을 해당 무대 칸을 클릭해주세요.",
                production: production,
                startMarks: startMarks,
                onBack: { step = .names },
                onDone: save
            )
        }
    }

    private var sceneName: String {
        guard let scene else { return "" }
        let scenes = (production.scenes ?? []).sorted { $0.order < $1.order }
        return scene.displayName(in: scenes)
    }

    // 고치기 시작할 때의 배치: 장면을 이미 고쳤으면 그 장면 것, 아니면 최초 상태
    private var startMarks: [StageMark] {
        production.stagePlacements(for: scene).map(\.mark)
    }

    private func save(_ marks: [StageMark]) {
        let placements = marks.map { StagePlacement(name: $0.name, kind: $0.kind, area: $0.area, x: $0.x, y: $0.y) }
        if let scene {
            (scene.placements ?? []).forEach(modelContext.delete)
            scene.placements = placements
            scene.hasOwnPlacements = true
        } else {
            (production.initialPlacements ?? []).forEach(modelContext.delete)
            production.initialPlacements = placements
        }
        dismiss()
    }
}

extension Production {
    // 이 장면에서 보여줄 무대 배치 (장면을 고친 적 없으면 최초 상태). 목록에서 지운 이름은 뺀다
    func stagePlacements(for scene: ShowScene?) -> [StagePlacement] {
        let placements = scene?.hasOwnPlacements == true ? scene?.placements : initialPlacements
        return (placements ?? []).filter { placement in
            switch placement.kind {
            case .cast: castNames.contains(placement.name)
            case .prop: propNames.contains(placement.name)
            }
        }
    }
}

// 최초상태무대배치02: 제목 · 배역/소품 카드 · 무대 미니맵 · 배치 완료
private struct StagePlacementEditor: View {
    let title: String
    let subtitle: String
    let production: Production
    let onBack: () -> Void   // "<" → 배우 · 소품 목록으로
    let onDone: ([StageMark]) -> Void

    @State private var marks: [StageMark]
    @State private var zoneFrames: [StageArea: CGRect] = [:]
    @State private var dragging: (mark: StageMark, location: CGPoint)?
    @State private var selected: StageMark?   // 고른 카드 (다음에 누르는 칸에 놓는다)

    init(
        title: String, subtitle: String, production: Production,
        startMarks: [StageMark], onBack: @escaping () -> Void, onDone: @escaping ([StageMark]) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.production = production
        self.onBack = onBack
        self.onDone = onDone
        _marks = State(initialValue: startMarks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            VStack(alignment: .leading, spacing: 30) {
                SheetBackButton(action: onBack)
                    .padding(.leading, -2)
                SheetHeader(title: title, subtitle: subtitle) { EmptyView() }
            }

            VStack(alignment: .trailing, spacing: 40) {
                VStack(alignment: .leading, spacing: 36) {
                    HStack(alignment: .top, spacing: 50) {
                        cardColumn(title: "배역", systemImage: "person", names: production.castNames, kind: .cast)
                        cardColumn(title: "소품", systemImage: "gift", names: production.propNames, kind: .prop)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("무대 미니맵")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.neutral500)
                        StageMinimap(
                            marks: marks,
                            style: .setup,
                            onDragChanged: { mark, location in dragging = (mark, location) },
                            onDragEnded: drop,
                            hiddenMarkID: dragging?.mark.id,
                            onTapZone: place,
                            onTapMark: { selected = selected?.id == $0.id ? nil : $0 },
                            onRemoveMark: { mark in
                                marks.removeAll { $0.id == mark.id }
                                if selected?.id == mark.id { selected = nil }
                            },
                            selectedMarkID: selected?.id,
                            isPlacing: selected != nil
                        )
                    }
                }

                Button("배치 완료") { onDone(marks) }
                    .buttonStyle(SheetSoftButtonStyle(fontSize: 15))
                    .frame(width: 130, height: 36)
                    .disabled(marks.isEmpty)   // 하나라도 놓으면 누를 수 있다
                    .opacity(marks.isEmpty ? 0.5 : 1)
                    .help(marks.isEmpty ? "배역이나 소품을 미니맵에 하나 이상 놓아주세요" : "")
            }
        }
        .padding(.horizontal, 50)
        .padding(.top, 47)
        .padding(.bottom, 47)
        .frame(width: 1049, height: 800, alignment: .top)
        .background(Color.white)   // 피그마 window-background = 흰색
        .coordinateSpace(.named(StageDrag.space))
        .onPreferenceChange(StageZoneFramesKey.self) { zoneFrames = $0 }
        // 끄는 중인 점 · 카드는 손가락(마우스)을 따라다닌다
        .overlay(alignment: .topLeading) {
            if let dragging {
                StageMarkView(mark: dragging.mark, style: .setup)
                    .position(dragging.location)
                    .allowsHitTesting(false)
            }
        }
    }

    // 배역 / 소품 카드 묶음: 제목 + 개수 + 카드 4개씩
    private func cardColumn(title: String, systemImage: String, names: [String], kind: StageItemKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16))
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color.neutral900)
                Text("\(names.count)개")
                    .font(.body)
                    .foregroundStyle(Color.neutral500)
            }

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(names, id: \.self) { name in
                        let mark = marks.first { $0.name == name && $0.kind == kind }
                            ?? StageMark(name: name, kind: kind, area: .stage, x: 0.5, y: 0.5)
                        StageNameCard(name: name, isSelected: selected?.id == mark.id)
                            .onTapGesture { selected = selected?.id == mark.id ? nil : mark }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 132)   // 3줄 넘으면 스크롤
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 고른 카드를 누른 구역에 놓는다. 무대면 그 칸에 (같은 칸 것들과 나란히), 상수 · 하수면 누른 자리에
    private func place(in area: StageArea, at point: CGPoint) {
        guard let mark = selected else { return }
        selected = nil
        marks.removeAll { $0.id == mark.id }

        var placed = mark
        placed.area = area
        if area == .stage {
            let cell = StageCell.index(x: point.x, y: point.y)
            placed.x = point.x
            placed.y = point.y
            marks.append(placed)
            // 같은 칸에 있는 것들을 가로로 고르게 다시 놓는다 (놓은 순서대로)
            let sameCell = marks.indices.filter { marks[$0].area == .stage && StageCell.index(x: marks[$0].x, y: marks[$0].y) == cell }
            for (i, index) in sameCell.enumerated() {
                let slot = StageCell.slot(i, of: sameCell.count, in: cell)
                marks[index].x = slot.x
                marks[index].y = slot.y
            }
        } else {
            // 이름이 구역 밖으로 삐져나가지 않게 가장자리는 조금 안쪽으로
            placed.x = min(max(point.x, 0.15), 0.85)
            placed.y = min(max(point.y, 0.2), 0.88)
            marks.append(placed)
        }
    }

    // 놓은 자리가 구역 안이면 그 구역 · 위치로, 밖이면 미니맵에서 뺀다
    private func drop(_ mark: StageMark, at location: CGPoint) {
        dragging = nil
        marks.removeAll { $0.id == mark.id }
        guard let (area, frame) = zoneFrames.first(where: { $0.value.contains(location) }).map({ ($0.key, $0.value) }) else { return }

        var placed = mark
        placed.area = area
        // 이름이 구역 밖으로 삐져나가지 않게 가장자리는 조금 안쪽으로
        placed.x = min(max((location.x - frame.minX) / frame.width, 0.08), 0.92)
        placed.y = min(max((location.y - frame.minY) / frame.height, 0.06), 0.88)
        marks.append(placed)
    }
}

// 위쪽 이름 카드. 고르면 보라 테두리 + 연보라 바탕 (피그마 1354:7911 장발장 카드), 마우스를 올려도 보라 테두리
private struct StageNameCard: View {
    let name: String
    var isSelected = false

    @State private var isHovered = false

    var body: some View {
        Text(name)
            .font(.system(size: 15))
            .foregroundStyle(isSelected || isHovered ? Color.brandPrimaryText : Color.neutral900)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 37)
            .background(
                isSelected ? Color.brandPrimarySubtle.opacity(0.5)
                    : isHovered ? Color.brandPrimarySubtle.opacity(0.2) : Color.neutral25,
                in: RoundedRectangle(cornerRadius: 3)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(isSelected || isHovered ? Color.brandPrimary : Color.brandPrimaryDisabled, lineWidth: 0.5)
            }
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

#Preview("최초 상태 배치") {
    StageSetupSheet(production: RehearsalPreviewData.production)
}
