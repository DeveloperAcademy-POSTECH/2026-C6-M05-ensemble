//
//  StageSetupSheet.swift
//  CueFlow
//
//  무대 배치 창.
//  처음("배치하기"): 배우 · 소품 목록 → 다음으로 → 무대 칸 설정 → 적용 완료 → 최초 상태 무대 배치 → 배치 완료
//  장면에서("수정하기"): 배우 · 소품 목록(이름 고치기) → 다음으로 → 무대 칸 설정 → 그 장면의 무대 배치
//  위쪽 이름 카드를 눌러 고른 뒤 놓을 무대 칸을 누른다 (피그마 1354:7896 — 끌기는 불편하다는 의견으로 바꿈).
//  놓인 점도 눌러서 고른 뒤 다른 칸을 누르면 옮겨진다. 칸 · 구역 안 자리는 자동 정렬. 빼기는 점 우클릭.
//  배치 완료를 눌러야 저장된다.
//

import SwiftUI
import SwiftData

struct StageSetupSheet: View {
    let production: Production
    let scene: ShowScene?          // nil = 최초 상태 배치, 있으면 그 장면의 배치

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private enum Step { case names, grid, placement }
    @State private var step: Step = .names

    init(production: Production, scene: ShowScene? = nil) {
        self.production = production
        self.scene = scene
    }

    var body: some View {
        switch step {
        case .names:
            CastPropListSheet(production: production, onBack: { dismiss() }) {
                step = .grid
            }
        case .grid:
            StageGridSheet(production: production, onBack: { step = .names }) {
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
                onBack: { step = .grid },
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
    let onBack: () -> Void   // "<" → 무대 칸 설정으로
    let onDone: ([StageMark]) -> Void

    @State private var marks: [StageMark]
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
        // 예전에 끌어서 놓은 자리도 열 때 자동 정렬 → 배치 완료를 누르면 그대로 저장된다
        _marks = State(initialValue: StageAutoLayout.arranged(startMarks, columns: production.stageGridColumns))
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
                            .font(.app(size: 15, weight: .semibold))
                            .foregroundStyle(Color.neutral500)
                        StageMinimap(
                            marks: marks,
                            style: .setup,
                            gridColumns: production.stageGridColumns,
                            onTapZone: place,
                            onTapMark: tapMark,
                            onRemoveMark: { mark in
                                marks.removeAll { $0.id == mark.id }
                                if selected?.id == mark.id { selected = nil }
                                marks = StageAutoLayout.arranged(marks, columns: production.stageGridColumns)
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
        .background(Color.appBackground)   // 피그마 window-background = 흰색
    }

    // 배역 / 소품 카드 묶음: 제목 + 개수 + 카드 4개씩
    private func cardColumn(title: String, systemImage: String, names: [String], kind: StageItemKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.app(size: 16))
                    Text(title)
                        .font(.app(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color.neutral900)
                Text("\(names.count)개")
                    .font(.appBody)
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

    // 고른 카드를 누른 구역 · 칸에 놓는다. 자리는 그 안에서 자동 정렬
    private func place(in area: StageArea, at point: CGPoint) {
        guard var placed = selected else { return }
        selected = nil
        marks.removeAll { $0.id == placed.id }
        placed.area = area
        placed.x = point.x
        placed.y = point.y
        marks.append(placed)
        marks = StageAutoLayout.arranged(marks, columns: production.stageGridColumns)
    }

    // 놓인 점 누르기: 다른 카드를 고른 중이면 그 점이 있는 칸에 놓고, 아니면 그 점을 고르거나 해제
    private func tapMark(_ mark: StageMark) {
        if let selected, selected.id != mark.id {
            place(in: mark.area, at: CGPoint(x: mark.x, y: mark.y))
        } else {
            selected = selected?.id == mark.id ? nil : mark
        }
    }
}

// 위쪽 이름 카드. 고르면 보라 테두리 + 연보라 바탕 (피그마 1354:7911 장발장 카드), 마우스를 올려도 보라 테두리
private struct StageNameCard: View {
    let name: String
    var isSelected = false

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(name)
            .font(.app(size: 15))
            .foregroundStyle(isSelected || isHovered ? Color.brandPrimaryText : Color.neutral900)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 37)
            .background(
                isSelected ? Color.stageCardSelected
                    : isHovered ? Color.brandPrimarySubtle.opacity(0.2) : Color.neutral25,
                in: RoundedRectangle(cornerRadius: 3)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(isSelected || isHovered ? Color.stageOptionSelectedBorder : Color.stageOptionBorder, lineWidth: colorScheme == .dark && !isSelected ? 1 : 0.5)
            }
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

#Preview("최초 상태 배치") {
    StageSetupSheet(production: RehearsalPreviewData.production)
}
