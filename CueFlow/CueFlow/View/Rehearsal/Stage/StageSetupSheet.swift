//
//  StageSetupSheet.swift
//  CueFlow
//
//  무대 배치 창.
//  처음("배치하기"): 배우 · 소품 목록 → 다음으로 → 최초 상태 무대 배치 → 배치 완료
//  장면에서("수정하기"): 배우 · 소품 목록(이름 고치기) → 다음으로 → 그 장면의 무대 배치
//  위쪽 이름 카드나 미니맵의 점을 끌어서 놓고, 미니맵 밖으로 끌면 뺀다. 배치 완료를 눌러야 저장된다.
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
            CastPropListSheet(production: production) {
                step = .placement
            }
        case .placement:
            StagePlacementEditor(
                title: scene == nil ? "최초 상태 무대 배치" : "\(sceneName) 무대 배치",
                subtitle: scene == nil
                    ? "배역과 소품의 최초 상태 무대 배치를 해주세요.\n모든 배역과 소품의 최초 위치를 해당 영역에 카드를 드래그해 배치해주세요."
                    : "이 장면에서 배역과 소품이 있는 자리로 옮겨주세요.\n미니맵 밖으로 끌면 이 장면에서 빠져요.",
                production: production,
                startMarks: startMarks,
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
    let onDone: ([StageMark]) -> Void

    @State private var marks: [StageMark]
    @State private var zoneFrames: [StageArea: CGRect] = [:]
    @State private var dragging: (mark: StageMark, location: CGPoint)?

    init(
        title: String, subtitle: String, production: Production,
        startMarks: [StageMark], onDone: @escaping ([StageMark]) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.production = production
        self.onDone = onDone
        _marks = State(initialValue: startMarks)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            SheetHeader(title: title, subtitle: subtitle) { EmptyView() }

            VStack(alignment: .trailing, spacing: 28) {
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
                            onDragChanged: { mark, location in dragging = (mark, location) },
                            onDragEnded: drop,
                            hiddenMarkID: dragging?.mark.id
                        )
                    }
                }

                Button("배치 완료") { onDone(marks) }
                    .buttonStyle(SheetPrimaryButtonStyle())
                    .frame(width: 101, height: 30)
                    .disabled(marks.isEmpty)   // 하나라도 놓으면 누를 수 있다
                    .help(marks.isEmpty ? "배역이나 소품을 미니맵에 하나 이상 놓아주세요" : "")
            }
        }
        .padding(50)
        .frame(width: 1049)
        .background(Color.neutral25)
        .coordinateSpace(.named(StageDrag.space))
        .onPreferenceChange(StageZoneFramesKey.self) { zoneFrames = $0 }
        // 끄는 중인 점 · 카드는 손가락(마우스)을 따라다닌다
        .overlay(alignment: .topLeading) {
            if let dragging {
                StageMarkView(mark: dragging.mark)
                    .position(dragging.location)
                    .allowsHitTesting(false)
            }
        }
    }

    // 배역 / 소품 카드 묶음: 제목 + 개수 + 카드 4개씩
    private func cardColumn(title: String, systemImage: String, names: [String], kind: StageItemKind) -> some View {
        VStack(alignment: .leading, spacing: 7) {
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
                        StageNameCard(name: name)
                            .gesture(
                                DragGesture(coordinateSpace: .named(StageDrag.space))
                                    .onChanged { dragging = (mark, $0.location) }
                                    .onEnded { drop(mark, at: $0.location) }
                            )
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 132)   // 3줄 넘으면 스크롤
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

// 위쪽 이름 카드. 마우스를 올리면 보라 테두리 (피그마 장발장 카드)
private struct StageNameCard: View {
    let name: String

    @State private var isHovered = false

    var body: some View {
        Text(name)
            .font(.system(size: 10.3, weight: .semibold))
            .foregroundStyle(isHovered ? Color.brandPrimaryText : Color.neutral900)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 37)
            .background(
                isHovered ? Color.brandPrimarySubtle.opacity(0.2) : Color.neutral25,
                in: RoundedRectangle(cornerRadius: 3)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(isHovered ? Color.brandPrimary : Color.brandPrimaryDisabled, lineWidth: 0.5)
            }
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

#Preview("최초 상태 배치") {
    StageSetupSheet(production: RehearsalPreviewData.production)
}
