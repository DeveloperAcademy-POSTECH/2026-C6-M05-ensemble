//
//  RehearsalStageMap.swift
//  CueFlow
//
//  리허설 모드 무대 배치도. 상수 | 무대(3×3 칸) | 하수 에 지금 장면 큐의 배역 · 소품을 큐 위치대로 보여준다.
//  큐 제목에 들어 있는 배역 · 소품 이름(대본 입력에서 확인한 목록)을 찾아서 그 큐의 위치에 띄운다.
//  예: "판틴 로켓, 편지" (무대 가운데) → 무대 가운데 칸에 판틴 · 로켓 · 편지
//  지금 큐의 배역 · 소품은 진하게, 나머지는 흐리게. 무대 큐는 끌어다 놓아 칸을 정한다 (Cue.stageCell).
//

import SwiftUI

enum StageItemKind {
    case cast   // 배역
    case prop   // 소품
}

// 배치도 위에 띄울 것 하나: 이름 + 이 자리에 이 이름이 나오는 큐들
struct StageItem: Identifiable {
    let name: String
    let kind: StageItemKind
    var cues: [Cue]

    var id: String { "\(kind)-\(name)" }
}

struct RehearsalStageMap: View {
    let cues: [Cue]               // 지금 장면의 큐 (트리거 순서대로)
    let currentCueIDs: Set<UUID>  // 지금 큐(트리거)의 큐들 → 진하게
    let production: Production    // 배역 · 소품 이름 목록

    @State private var isEditingNames = false   // "배역 · 소품 목록" 창

    // 큐 제목에서 찾은 배역 · 소품 (배역 먼저). "공장장"을 찾았으면 그 안의 "공장"은 뺀다
    private func items(in title: String) -> [(String, StageItemKind)] {
        func found(_ names: [String]) -> [String] {
            names.filter { name in
                // "노동자들" 배역은 큐의 "노동자"로도 찾는다
                title.contains(name) || (name.hasSuffix("들") && name.count > 2 && title.contains(name.dropLast()))
            }
        }
        let all = found(production.castNames).map { ($0, StageItemKind.cast) }
            + found(production.propNames).map { ($0, StageItemKind.prop) }
        return all.filter { item in
            !all.contains { $0.0 != item.0 && $0.0.contains(item.0) }
        }
    }

    // 큐들 → 자리마다 겹치지 않게 모은 배역 · 소품
    private func stageItems(_ cues: [Cue]) -> [StageItem] {
        var result: [StageItem] = []
        for cue in cues {
            for (name, kind) in items(in: cue.title) {
                if let index = result.firstIndex(where: { $0.name == name && $0.kind == kind }) {
                    result[index].cues.append(cue)
                } else {
                    result.append(StageItem(name: name, kind: kind, cues: [cue]))
                }
            }
        }
        return result
    }

    private func cues(at position: CuePosition) -> [Cue] {
        cues.filter { $0.position == position }
    }

    // 무대 큐 중 칸을 아직 안 정한 것
    private var unplacedItems: [StageItem] {
        stageItems(cues(at: .stage).filter { $0.stageCell == nil })
    }

    private var hasNames: Bool {
        !production.castNames.isEmpty || !production.propNames.isEmpty
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
        .sheet(isPresented: $isEditingNames) {
            CastPropListSheet(production: production)
        }
    }

    // 상수 / 하수: 칸 없이 위에서부터 나열
    private func sideZone(_ position: CuePosition) -> some View {
        VStack(spacing: 8) {
            zoneLabel(position.rawValue)
            ForEach(stageItems(cues(at: position))) { item in
                StageItemChip(item: item, currentCueIDs: currentCueIDs)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // 비어 있어도 구역 크기 그대로
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
                            let index = row * 3 + column
                            StageCellView(
                                index: index,
                                items: stageItems(cues(at: .stage).filter { $0.stageCell == index }),
                                currentCueIDs: currentCueIDs,
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

    // 칸을 아직 안 정한 무대 큐의 배역 · 소품 + 이름 직접 추가. 여기로 끌어다 놓으면 칸이 비워진다.
    private var unplacedRow: some View {
        HStack(spacing: 8) {
            Text("칸 미정")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if !hasNames {
                        Text("대본을 불러오거나 배역 · 소품 목록에 이름을 넣으면 큐 위치에 나와요")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else if unplacedItems.isEmpty {
                        Text("무대 큐를 모두 배치했어요")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    ForEach(unplacedItems) { item in
                        StageItemChip(item: item, currentCueIDs: currentCueIDs)
                            .fixedSize()
                    }
                }
            }

            Button {
                isEditingNames = true
            } label: {
                Label("배역 · 소품 목록", systemImage: "list.bullet")
                    .font(.caption)
            }
            .buttonStyle(.link)
            .fixedSize()
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

// 무대 3×3 중 한 칸. 배역 · 소품을 끌어다 놓으면 그 큐가 이 칸으로 정해진다.
struct StageCellView: View {
    let index: Int
    let items: [StageItem]        // 이 칸에 있는 배역 · 소품
    let currentCueIDs: Set<UUID>
    let allCues: [Cue]            // 끌어온 큐를 찾기 위한 지금 장면 전체 큐

    @State private var isTargeted = false   // 끌고 이 칸 위에 올라와 있는지

    private var chips: some View {
        ForEach(items) { item in
            StageItemChip(item: item, currentCueIDs: currentCueIDs)
        }
    }

    var body: some View {
        // 한 칸에 여럿이면 옆으로 나란히, 넘치면 다음 줄
        ViewThatFits {
            HStack(alignment: .top, spacing: 8) { chips }
            VStack(spacing: 6) { chips }
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 피그마엔 칸 선이 없어서, 끌고 올라왔을 때만 칸을 보여 준다
        .background(
            isTargeted ? Color.brandPrimarySubtle : Color.clear,
            in: RoundedRectangle(cornerRadius: 4)
        )
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.brandPrimaryDisabled, style: StrokeStyle(lineWidth: 1, dash: [3]))
            }
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

// 배치도 위 배역 · 소품 하나 (피그마 리허설모드 무대 배치도)
// 배역 = 보라 동그라미 + 아래 이름, 소품 = 흰 상자(연보라 테두리) 안에 점 + 이름.
// 지금 큐에 나오면 진하게, 아니면 흐리게. 무대 큐면 끌어서 칸을 옮긴다 (이 이름이 나오는 큐가 같이 옮겨진다).
struct StageItemChip: View {
    let item: StageItem
    let currentCueIDs: Set<UUID>

    private var isCurrent: Bool { item.cues.contains { currentCueIDs.contains($0.id) } }

    var body: some View {
        let chip = Group {
            switch item.kind {
            case .cast: castMark
            case .prop: propMark
            }
        }
        .opacity(isCurrent || currentCueIDs.isEmpty ? 1 : 0.4)
        .contentShape(Rectangle())   // 글자 사이 빈 곳을 잡아도 끌리게
        .help(item.cues.map(\.title).joined(separator: "\n"))   // 어느 큐에서 나왔는지

        let stageCues = item.cues.filter { $0.position == .stage }
        if stageCues.isEmpty {
            chip
        } else {
            chip.draggable(stageCues.map(\.id.uuidString).joined(separator: ","))   // 끌 때 큐 id들을 글자로 넘긴다
        }
    }

    // 배역: 15pt 동그라미 + 아래 이름
    private var castMark: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.brandPrimaryHover)
                .frame(width: 15, height: 15)
            label
        }
        .padding(.horizontal, 4)
    }

    // 소품: 흰 상자 + 점 + 이름
    private var propMark: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.brandPrimaryDisabled)
                .frame(width: 7, height: 7)
            label
        }
        .padding(.horizontal, 8)
        .frame(height: 25)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color.brandPrimaryDisabled, lineWidth: 1)
        }
    }

    private var label: some View {
        Text(item.name)
            .font(.system(size: 10))
            .lineLimit(1)
            .fixedSize()
    }
}

extension Cue {
    // 끌어다 놓은 id 글자들("id,id")로 큐 찾기
    static func find(_ ids: [String], in cues: [Cue]) -> [Cue] {
        let all = Set(ids.flatMap { $0.split(separator: ",").map(String.init) })
        return cues.filter { all.contains($0.id.uuidString) }
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
    let production = RehearsalPreviewData.production
    let cues = RehearsalPreviewData.sceneCues
    RehearsalStageMap(cues: cues, currentCueIDs: [cues[cues.count - 1].id], production: production)
        .frame(width: 1009, height: 378)
        .padding()
}
