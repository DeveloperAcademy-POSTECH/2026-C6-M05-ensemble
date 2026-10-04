//
//  CueGridView.swift
//  CueFlow
//
//  메인 큐 화면의 표: 행 = 파트, 열 = 씬, 칸 = 그 파트의 그 씬 큐들 (트리거 순서대로)
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
    @Environment(CueStore.self) private var store

    var body: some View {
        FrozenHeaderScrollView {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                // 맨 윗줄: 씬
                GridRow {
                    Text("파트 / 씬")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(hex: 0x7A7A7A))
                        .padding(.leading, 15)
                        .frame(width: Metrics.partColumnWidth, height: Metrics.headerHeight, alignment: .leading)
                        .gridLines(leading: true, top: true)
                        .pinned(x: true, y: true)
                    ForEach(store.scenes) { scene in
                        SceneHeaderCell(scene: scene)
                            .frame(width: Metrics.sceneColumnWidth, height: Metrics.headerHeight)
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
                        ForEach(store.scenes) { scene in
                            CueCell(pairs: store.cuePairs(partID: part.id, sceneID: scene.id),
                                    partID: part.id, sceneID: scene.id)
                                .frame(width: Metrics.sceneColumnWidth)
                                .frame(minHeight: Metrics.rowMinHeight, maxHeight: .infinity, alignment: .top)
                                .gridLines()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 칸

private struct SceneHeaderCell: View {
    let scene: ShowScene

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(scene.name).font(.system(size: 12.5))
            Text(scene.subtitle).font(.system(size: 10.5))
        }
        .foregroundStyle(Color(hex: 0x111827))
        .lineLimit(1)
        .padding(.leading, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: 0xC9CED6)))
        .padding(5)
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
private struct CueCell: View {
    let pairs: [(trigger: Trigger, cue: Cue)]
    let partID: Part.ID
    let sceneID: ShowScene.ID
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
                AddCuePopup(partID: partID, sceneID: sceneID) { isAdding = false }
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
        // 💬 주석 · ✓ 확인 현황 버튼 (B: View/Card). 카드 오른쪽 아래
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 4) {
                CommentCountButton(cueID: cue.id)
                CheckCountButton(cueID: cue.id)
            }
                .padding(.trailing, 10)
                .padding(.bottom, 8)
        }
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
