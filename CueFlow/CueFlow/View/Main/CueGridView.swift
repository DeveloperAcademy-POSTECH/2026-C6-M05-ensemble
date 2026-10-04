//
//  CueGridView.swift
//  CueFlow
//
//  메인 큐 화면의 표: 행 = 파트, 열 = 씬(씬 단위) 또는 한 씬의 트리거(트리거 단위)
//  칸 = 그 파트의 그 씬/트리거 큐들 (트리거 순서대로)
//

import SwiftUI

private enum Metrics {
    static let partColumnWidth: CGFloat = 190
    static let sceneColumnWidth: CGFloat = 251
    static let headerHeight: CGFloat = 61
    static let rowMinHeight: CGFloat = 98
    static let line = Color(hex: 0xDCDCDC)
}

struct CueGridView: View {
    // 씬 단위: 열 = 씬 / 트리거 단위: 열 = 한 씬의 트리거
    enum Mode: Hashable {
        case scenes
        case triggers(ShowScene.ID)
    }

    var mode: Mode = .scenes
    var onSelectScene: (ShowScene.ID) -> Void = { _ in }   // 씬 헤더를 누르면 그 씬의 트리거 단위로
    var highlightedSceneID: ShowScene.ID?                  // 방금 추가한 씬: 그 열로 스크롤 + 헤더 강조

    @Environment(CueStore.self) private var store

    var body: some View {
        ScrollViewReader { proxy in
            grid
                .task(id: highlightedSceneID) {
                    guard let highlightedSceneID else { return }
                    await Task.yield()   // 새 열이 그려진 뒤에 스크롤
                    withAnimation { proxy.scrollTo(highlightedSceneID, anchor: .topTrailing) }
                }
        }
    }

    private var grid: some View {
        FrozenHeaderScrollView {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                // 맨 윗줄: 씬 또는 트리거
                GridRow {
                    Text(mode == .scenes ? "파트 / 씬" : "파트 / 트리거")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(hex: 0x7A7A7A))
                        .padding(.leading, 15)
                        .frame(width: Metrics.partColumnWidth, height: Metrics.headerHeight, alignment: .leading)
                        .gridLines(leading: true, top: true)
                        .pinned(x: true, y: true)
                    ForEach(columns) { column in
                        ColumnHeaderCell(title: column.title, subtitle: column.subtitle,
                                         isHighlighted: column.id == highlightedSceneID,
                                         action: mode == .scenes ? { onSelectScene(column.sceneID) } : nil)
                            .frame(width: Metrics.sceneColumnWidth, height: Metrics.headerHeight)
                            .id(column.id)
                            .gridLines(top: true)
                            .pinned(y: true)
                    }
                }

                // 파트마다 한 줄
                ForEach(store.visibleParts) { part in
                    GridRow {
                        PartHeaderCell(part: part, count: store.cueCount(partID: part.id))
                            .frame(width: Metrics.partColumnWidth)
                            .frame(maxHeight: .infinity)
                            .gridCellUnsizedAxes(.vertical)
                            .gridLines(leading: true)
                            .pinned(x: true)
                        ForEach(columns) { column in
                            CueCell(pairs: pairs(partID: part.id, column: column),
                                    partID: part.id, sceneID: column.sceneID,
                                    triggerText: column.trigger?.text ?? "")
                                .frame(width: Metrics.sceneColumnWidth)
                                .frame(minHeight: Metrics.rowMinHeight, maxHeight: .infinity, alignment: .top)
                                .gridLines()
                        }
                    }
                }
            }
        }
    }

    // MARK: - 열

    private struct Column: Identifiable {
        let id: UUID
        let title: String
        let subtitle: String
        let sceneID: ShowScene.ID
        let trigger: Trigger?   // 트리거 단위일 때만 (트리거가 없는 씬의 빈 열은 nil)
    }

    private var columns: [Column] {
        switch mode {
        case .scenes:
            return store.scenes.map {
                Column(id: $0.id, title: $0.name, subtitle: $0.subtitle, sceneID: $0.id, trigger: nil)
            }
        case .triggers(let sceneID):
            // 헤더 이름: S#씬번호 - 트리거순서 (예: S#1 - 2)
            let sceneNumber = (store.scenes.firstIndex { $0.id == sceneID } ?? 0) + 1
            let triggers = store.triggers(in: sceneID)
            // 트리거가 없는 씬(새로 추가한 씬 등)은 빈 열 하나. 여기서 Add new로 첫 트리거를 만든다
            guard !triggers.isEmpty else {
                return [Column(id: sceneID, title: "S#\(sceneNumber)", subtitle: "아직 트리거가 없어요",
                               sceneID: sceneID, trigger: nil)]
            }
            return triggers.map {
                Column(id: $0.id, title: "S#\(sceneNumber) - \($0.order)", subtitle: $0.text,
                       sceneID: sceneID, trigger: $0)
            }
        }
    }

    // 칸에 들어갈 (트리거, 큐). 씬 단위는 트리거 순서대로, 트리거 단위는 그 트리거의 큐만
    private func pairs(partID: Part.ID, column: Column) -> [(trigger: Trigger, cue: Cue)] {
        guard let trigger = column.trigger else {
            return store.cuePairs(partID: partID, sceneID: column.sceneID)
        }
        return store.cues(partID: partID, triggerID: trigger.id).map { (trigger: trigger, cue: $0) }
    }
}

// MARK: - 칸

// 열 헤더: 씬(이름, 부제) 또는 트리거(S#1 - 1, 트리거 내용). action이 있으면 누를 수 있음
private struct ColumnHeaderCell: View {
    let title: String
    let subtitle: String
    var isHighlighted = false
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 12.5))
            Text(subtitle).font(.system(size: 10.5))
        }
        .foregroundStyle(Color(hex: 0x111827))
        .lineLimit(1)
        .padding(.leading, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(isHighlighted ? Color(hex: 0xE8ECF8) : .white, in: .rect(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4)
            .stroke(isHighlighted ? Color(hex: 0x4A6BD6) : Color(hex: 0xC9CED6), lineWidth: isHighlighted ? 1.5 : 1))
        .animation(.easeOut(duration: 0.4), value: isHighlighted)
        .padding(5)
        .contentShape(.rect)
    }
}

private struct PartHeaderCell: View {
    let part: Part
    let count: Int

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: 0xF3F4F6))
                .frame(width: 5)
            VStack(alignment: .leading, spacing: 8) {
                Text(part.name)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color(hex: 0x111827))
                Text("총 \(count)개")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(hex: 0x6B7280))
            }
            .padding(.leading, 10)
            .padding(.top, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// 큐가 있으면 회색 칸 + 카드들 + Add new, 비어 있으면 마우스를 올렸을 때만 Add new
// Add new를 누르면 이 칸(파트 × 씬)에 큐를 넣는 입력 팝업이 뜬다
// 트리거 단위 칸이면 그 트리거가 미리 채워진 채로 뜬다
private struct CueCell: View {
    let pairs: [(trigger: Trigger, cue: Cue)]
    let partID: Part.ID
    let sceneID: ShowScene.ID
    var triggerText = ""
    @State private var isHovering = false
    @State private var isAdding = false

    var body: some View {
        Group {
            if pairs.isEmpty {
                // 팝업이 떠 있는 동안은 마우스가 나가도 버튼(팝업 기준점)을 유지
                if isHovering || isAdding {
                    addNewButton
                        .padding(.horizontal, 15)
                        .padding(.top, 12)
                }
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(pairs, id: \.cue.id) { pair in
                        TempCueCard(cue: pair.cue, trigger: pair.trigger)
                    }
                    addNewButton
                        .padding(.horizontal, 3)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .background(Color(hex: 0xD9D9D9), in: .rect(cornerRadius: 6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(.rect)
        .onHover { isHovering = $0 }
    }

    private var addNewButton: some View {
        AddNewButton { isAdding = true }
            .popover(isPresented: $isAdding, arrowEdge: .bottom) {
                AddCuePopup(partID: partID, sceneID: sceneID, triggerText: triggerText) { isAdding = false }
            }
    }
}

private struct AddNewButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .foregroundStyle(Color(hex: 0x7A7A7A))
                Text("Add new")
                    .foregroundStyle(Color(hex: 0x59636E))
            }
            .font(.system(size: 12, weight: .medium))
            .frame(height: 19)
        }
        .buttonStyle(.plain)
    }
}

// 임시 카드. B의 CueCardView가 나오면 이 자리를 교체
private struct TempCueCard: View {
    let cue: Cue
    let trigger: Trigger

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(cue.action).font(.system(size: 11, weight: .medium))
                Text(trigger.text).font(.system(size: 10))
            }
            .foregroundStyle(Color(hex: 0x2E2E2E))
            .lineLimit(1)
            Spacer(minLength: 0)
            if let position = cue.position {
                Text(position.rawValue)
                    .font(.system(size: 8))
                    .foregroundStyle(Color(hex: 0x111827))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: 0xEFEFEF), in: .capsule)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(.white, in: .rect(cornerRadius: 8))
    }
}

// MARK: - 선

private extension View {
    // 칸마다 오른쪽·아래 선. 표 바깥 테두리는 맨 윗줄(top)과 왼쪽 열(leading)이 그림
    func gridLines(leading: Bool = false, top: Bool = false) -> some View {
        overlay(alignment: .trailing) { Metrics.line.frame(width: 1) }
            .overlay(alignment: .bottom) { Metrics.line.frame(height: 1) }
            .overlay(alignment: .leading) { if leading { Metrics.line.frame(width: 1) } }
            .overlay(alignment: .top) { if top { Metrics.line.frame(height: 1) } }
    }
}

#Preview {
    CueGridView()
        .environment(CueStore.sample())
        .frame(width: 1450, height: 800)
}
