//
//  StageMinimap.swift
//  CueFlow
//
//  무대 미니맵 (피그마 리허설모드_ver1 · 최초상태무대배치02).
//  하수 | 무대(무대 칸 설정대로 점선으로 나눔) | 상수 (관객석에서 봤을 때 오른쪽이 상수) 위에 배역(●) · 소품(▲)을 놓은 자리에 보여준다.
//  아래에 "관객석"과 범례. 리허설 화면(보기만)과 배치 창(카드 고르고 칸 누르기)에서 같이 쓴다.
//

import SwiftUI

// 미니맵에 놓인 배역 · 소품 하나. 배치 창에서는 저장 전까지 이걸로 고친다
struct StageMark: Identifiable, Equatable {
    var name: String
    var kind: StageItemKind
    var area: StageArea
    var x: Double
    var y: Double

    var id: String { "\(kind.rawValue)-\(name)" }
}

extension StagePlacement {
    var mark: StageMark {
        StageMark(name: name, kind: kind, area: area, x: x, y: y)
    }
}

// 리허설 화면과 배치 창은 글자 · 점 크기가 다르다
// (피그마 리허설모드 951:9052 / 최초상태무대배치02 951:9819)
enum StageMinimapStyle {
    case rehearsal, setup

    var zoneLabelSize: CGFloat { self == .rehearsal ? 15 : 14 }
    var castSize: CGFloat { self == .rehearsal ? 17 : 15 }
    var propSize: CGSize { self == .rehearsal ? CGSize(width: 15, height: 13) : CGSize(width: 12.5, height: 11) }
    var nameSize: CGFloat { 15 }
    var nameWeight: Font.Weight { self == .rehearsal ? .semibold : .regular }   // 배치 창은 목록 창 이름 칸과 같은 레귤러 15
}

struct StageMinimap: View {
    let marks: [StageMark]
    var style: StageMinimapStyle = .rehearsal
    var highlightedIDs: Set<String> = []   // 리허설에서 지금 큐가 옮긴 것 → 둘레가 빛난다
    var gridColumns = 3                     // 무대 칸 설정 (Production.stageGridColumns). 0 = 구분선 없음

    // 배치 창에서만: 구역을 누르면 (구역, 누른 자리 0~1) / 놓인 점을 누르면 그 점 / 놓인 점 빼기
    var onTapZone: ((StageArea, CGPoint) -> Void)?
    var onTapMark: ((StageMark) -> Void)?
    var onRemoveMark: ((StageMark) -> Void)?
    var selectedMarkID: String?   // 고른 카드 → 그 점 둘레가 빛난다
    var isPlacing = false         // 카드를 골랐으면 마우스를 올린 칸을 연보라로

    @State private var hoveredCell: Int?   // 무대 칸 번호 (왼쪽 위부터 0)

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 0) {
                zone(.hasu)
                    .frame(width: 166)
                zone(.stage)
                    .padding(.leading, 20)
                    .padding(.trailing, 22)
                zone(.sangsu)
                    .frame(width: 172)
            }
            .frame(height: 255)

            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 166, height: 1)
                Text("관객석")
                    .font(.system(size: style.zoneLabelSize, weight: .semibold))
                    .foregroundStyle(Color.neutral400)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 20)
                    .padding(.trailing, 22)
                legend
                    .frame(width: 172, alignment: .trailing)
            }
        }
    }

    // 구역 하나: 이름 + (무대면 점선 · 번호) + 놓인 배역 · 소품
    private func zone(_ area: StageArea) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                // 카드를 고른 채 마우스를 올린 무대 칸 (피그마 1354:7972)
                if area == .stage, isPlacing, gridColumns > 0, let hoveredCell {
                    let n = CGFloat(gridColumns)
                    Rectangle()
                        .fill(Color.brandPrimarySubtle.opacity(0.8))
                        .frame(width: size.width / n, height: size.height / n)
                        .offset(
                            x: size.width * CGFloat(hoveredCell % gridColumns) / n,
                            y: size.height * CGFloat(hoveredCell / gridColumns) / n
                        )
                }
                if area == .stage, gridColumns > 0 {
                    StageGridLines(columns: gridColumns)
                        .stroke(Color.stageGridLine, style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    cellNumbers(size: size)
                }

                Text(area.rawValue)
                    .font(.system(size: style.zoneLabelSize, weight: .semibold))
                    .foregroundStyle(Color.stageZoneLabel)
                    .frame(width: size.width)
                    .offset(y: 26)

                ForEach(marks.filter { $0.area == area }) { mark in
                    markView(mark)
                        .position(x: mark.x * size.width, y: mark.y * size.height)
                        .animation(.easeInOut(duration: 0.35), value: mark)   // 큐를 넘기면 스르륵 옮겨진다
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture { location in
                onTapZone?(area, CGPoint(x: location.x / size.width, y: location.y / size.height))
            }
            .onContinuousHover { phase in
                guard area == .stage, onTapZone != nil, gridColumns > 0 else { return }
                switch phase {
                case .active(let location):
                    hoveredCell = StageCell.index(x: location.x / size.width, y: location.y / size.height, columns: gridColumns)
                case .ended:
                    hoveredCell = nil
                }
            }
        }
        .background(
            area == .stage ? Color.neutral25 : Color.stageSideZone,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.stageBorder, lineWidth: 1)
        }
    }

    // 무대 칸 번호 1~n² (각 칸 왼쪽 위). 칸이 작아지면 번호도 안쪽으로 붙인다
    private func cellNumbers(size: CGSize) -> some View {
        let n = CGFloat(gridColumns)
        let inset: CGFloat = gridColumns > 3 ? 6 : 12
        return ForEach(0..<gridColumns * gridColumns, id: \.self) { index in
            Text("\(index + 1)")
                .font(.system(size: gridColumns > 4 ? 10 : 12))
                .foregroundStyle(Color.stageCellNumber)
                .offset(
                    x: size.width * CGFloat(index % gridColumns) / n + inset,
                    y: size.height * CGFloat(index / gridColumns) / n + inset - 2
                )
        }
    }

    @ViewBuilder
    private func markView(_ mark: StageMark) -> some View {
        let isHighlighted = highlightedIDs.contains(mark.id) || mark.id == selectedMarkID
        let view = StageMarkView(mark: mark, style: style, isHighlighted: isHighlighted)
        if onTapMark != nil {
            view
                .help("눌러서 고른 뒤 다른 칸을 누르면 옮겨져요 · 우클릭으로 빼기")
                .onTapGesture { onTapMark?(mark) }
                .contextMenu {
                    Button("미니맵에서 빼기") { onRemoveMark?(mark) }
                }
        } else {
            view
        }
    }

    // 오른쪽 아래 "● 배우 ▲ 소품" (피그마 최초상태무대배치02 크기 — 리허설 화면도 이걸로)
    private var legend: some View {
        HStack(spacing: 7) {
            HStack(spacing: 3) {
                Circle()
                    .fill(Color.brandPrimary)
                    .frame(width: 6, height: 6)
                Text("배우")
            }
            HStack(spacing: 3) {
                StageTriangle()
                    .fill(style == .setup ? Color.stageLegendPropSetup : Color.stagePropMark)
                    .frame(width: 7, height: 6)
                Text("소품")
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(Color.legendText)
        .padding(.horizontal, 13)
        .frame(height: 23)
        .background(Color.legendBackground, in: Capsule())
    }
}

// 배역 = 보라 동그라미, 소품 = 민트 세모. 이름은 아래에.
// 동그라미 · 세모의 가운데가 놓은 자리에 오도록, 이름은 겹쳐서 아래로 내린다
struct StageMarkView: View {
    let mark: StageMark
    var style: StageMinimapStyle = .rehearsal
    var isHighlighted = false

    var body: some View {
        Group {
            switch mark.kind {
            case .cast:
                Circle()
                    .fill(Color.brandPrimary)
                    .frame(width: style.castSize, height: style.castSize)
            case .prop:
                StageTriangle()
                    .fill(style == .setup ? Color.stagePropMarkSetup : Color.stagePropMark)
                    .frame(width: style.propSize.width, height: style.propSize.height)
            }
        }
        .background {
            if isHighlighted {
                Circle()
                    .fill(Color.brandPrimarySubtle)
                    .frame(width: 28, height: 28)
            }
        }
        .overlay(alignment: .top) {
            Text(mark.name)
                .font(.system(size: style.nameSize, weight: style.nameWeight))
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .fixedSize()
                .offset(y: mark.kind == .cast ? style.castSize + 4 : style.propSize.height + 2)
        }
        .padding(6)                  // 잡기 쉽게
        .contentShape(Rectangle())
    }

    private var nameColor: Color {
        if style == .setup { return .brandPrimaryText }
        return mark.kind == .cast ? .neutral900 : .neutral800
    }
}

// 소품 세모
struct StageTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// 무대 n×n 칸 번호 (0부터, 왼쪽 위부터). 자리(0~1)로 칸 찾기 · 칸 안에 나란히 놓을 자리 · 칸 가운데
enum StageCell {
    static func index(x: Double, y: Double, columns: Int) -> Int {
        let column = min(max(Int(x * Double(columns)), 0), columns - 1)
        let row = min(max(Int(y * Double(columns)), 0), columns - 1)
        return row * columns + column
    }

    // 한 칸에 n개면 가로로 고르게 나눈 i번째 자리 (세로는 칸 가운데)
    static func slot(_ i: Int, of n: Int, in cell: Int, columns: Int) -> CGPoint {
        let width = 1 / Double(columns)
        let left = Double(cell % columns) * width
        let top = Double(cell / columns) * width
        return CGPoint(x: left + width * Double(i + 1) / Double(n + 1), y: top + width / 2)
    }

    static func center(of cell: Int, columns: Int) -> CGPoint {
        CGPoint(
            x: (Double(cell % columns) + 0.5) / Double(columns),
            y: (Double(cell / columns) + 0.5) / Double(columns)
        )
    }
}

// 놓인 것들을 칸 · 구역 안에서 자동으로 줄 세운다. 사용자는 어느 칸인지만 고른다 (UT: 세부 위치를 정하는 줄 알고 재정렬을 오류로 인식)
enum StageAutoLayout {
    static func arranged(_ marks: [StageMark], columns: Int) -> [StageMark] {
        var result = marks
        // 놓은 순서대로 칸 · 구역별로 모은다 (칸이 없는 곳은 cell = nil)
        var groups: [String: [Int]] = [:]
        for index in result.indices {
            let mark = result[index]
            let cell = mark.area == .stage && columns > 0 ? StageCell.index(x: mark.x, y: mark.y, columns: columns) : nil
            groups["\(mark.area.rawValue)-\(cell ?? -1)", default: []].append(index)
        }
        for indices in groups.values {
            let first = result[indices[0]]
            for (order, index) in indices.enumerated() {
                let point: CGPoint
                if first.area == .stage, columns > 0 {
                    let cell = StageCell.index(x: first.x, y: first.y, columns: columns)
                    point = StageCell.slot(order, of: indices.count, in: cell, columns: columns)
                } else {
                    point = zoneSlot(order, of: indices.count, perRow: first.area == .stage ? 6 : 2)
                }
                result[index].x = point.x
                result[index].y = point.y
            }
        }
        return result
    }

    // 칸이 없는 구역(상수 · 하수 · 기본 무대): 구역 이름 아래에 왼쪽 위부터 차례로
    private static func zoneSlot(_ i: Int, of n: Int, perRow: Int) -> CGPoint {
        let rows = (n + perRow - 1) / perRow
        let step = rows > 1 ? min(0.2, 0.58 / Double(rows - 1)) : 0
        let column = i % perRow
        let row = i / perRow
        return CGPoint(x: (Double(column) + 0.5) / Double(perRow), y: 0.3 + Double(row) * step)
    }
}

// 무대를 n×n으로 나누는 점선 (세로 n-1줄 + 가로 n-1줄). 무대 칸 설정 창 미리보기에서도 쓴다
struct StageGridLines: Shape {
    let columns: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard columns > 1 else { return path }
        for step in 1..<columns {
            let x = rect.width * CGFloat(step) / CGFloat(columns)
            path.move(to: CGPoint(x: x, y: 1))
            path.addLine(to: CGPoint(x: x, y: rect.height - 1))
            let y = rect.height * CGFloat(step) / CGFloat(columns)
            path.move(to: CGPoint(x: 1, y: y))
            path.addLine(to: CGPoint(x: rect.width - 1, y: y))
        }
        return path
    }
}

#Preview {
    StageMinimap(marks: RehearsalPreviewData.stageMarks)
        .frame(width: 950)
        .padding()
}
