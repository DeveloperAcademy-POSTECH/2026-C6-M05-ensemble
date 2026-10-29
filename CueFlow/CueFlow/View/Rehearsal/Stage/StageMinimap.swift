//
//  StageMinimap.swift
//  CueFlow
//
//  무대 미니맵 (피그마 리허설모드_ver1 · 최초상태무대배치02).
//  상수 | 무대(점선으로 1~9 나눔) | 하수 위에 배역(●) · 소품(▲)을 놓은 자리에 보여준다.
//  아래에 "관객석"과 범례. 리허설 화면(보기만)과 배치 창(끌어서 옮기기)에서 같이 쓴다.
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

// 배치 창에서 끌 때 쓰는 좌표 이름 + 구역 위치를 배치 창으로 올려 보내는 키
enum StageDrag {
    static let space = "stageDrag"
}

struct StageZoneFramesKey: PreferenceKey {
    static let defaultValue: [StageArea: CGRect] = [:]
    static func reduce(value: inout [StageArea: CGRect], nextValue: () -> [StageArea: CGRect]) {
        value.merge(nextValue()) { $1 }
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

    // 배치 창에서만: 점을 끄는 중 / 놓음. nil이면 보기만
    var onDragChanged: ((StageMark, CGPoint) -> Void)?
    var onDragEnded: ((StageMark, CGPoint) -> Void)?
    var hiddenMarkID: String?   // 끄는 중인 점은 제자리에서 숨긴다

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 0) {
                zone(.sangsu)
                    .frame(width: 166)
                zone(.stage)
                    .padding(.leading, 20)
                    .padding(.trailing, 22)
                zone(.hasu)
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
                if area == .stage {
                    StageGridLines()
                        .stroke(Color.brandPrimaryDisabled, style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    cellNumbers(size: size)
                }

                Text(area.rawValue)
                    .font(.system(size: style.zoneLabelSize, weight: .semibold))
                    .foregroundStyle(Color.neutral400)
                    .frame(width: size.width)
                    .offset(y: 26)

                ForEach(marks.filter { $0.area == area }) { mark in
                    markView(mark)
                        .position(x: mark.x * size.width, y: mark.y * size.height)
                        .animation(.easeInOut(duration: 0.35), value: mark)   // 큐를 넘기면 스르륵 옮겨진다
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .background(
            area == .stage ? Color.neutral25 : Color.brandPrimarySubtle.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.brandPrimaryDisabled, lineWidth: 1)
        }
        // 배치 창이 "어느 구역에 놓았는지" 알 수 있게 구역 위치를 올려 보낸다
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: StageZoneFramesKey.self,
                    value: [area: geometry.frame(in: .named(StageDrag.space))]
                )
            }
        }
    }

    // 무대 칸 번호 1~9 (각 칸 왼쪽 위)
    private func cellNumbers(size: CGSize) -> some View {
        ForEach(0..<9, id: \.self) { index in
            Text("\(index + 1)")
                .font(.system(size: 12))
                .foregroundStyle(Color.brandPrimaryDisabled)
                .offset(
                    x: size.width * CGFloat(index % 3) / 3 + 12,
                    y: size.height * CGFloat(index / 3) / 3 + 10
                )
        }
    }

    @ViewBuilder
    private func markView(_ mark: StageMark) -> some View {
        let view = StageMarkView(mark: mark, style: style, isHighlighted: highlightedIDs.contains(mark.id))
            .opacity(mark.id == hiddenMarkID ? 0 : 1)
        if let onDragChanged, let onDragEnded {
            view
                .help("끌어서 옮기기 · 미니맵 밖으로 끌면 빠져요")
                .gesture(
                    DragGesture(coordinateSpace: .named(StageDrag.space))
                        .onChanged { onDragChanged(mark, $0.location) }
                        .onEnded { onDragEnded(mark, $0.location) }
                )
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
                    .fill(Color.stagePropMark)
                    .frame(width: 7, height: 6)
                Text("소품")
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(Color.neutral500)
        .padding(.horizontal, 13)
        .frame(height: 23)
        .background(Color.neutral100, in: Capsule())
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
                    .fill(Color.stagePropMark)
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

// 무대를 3×3으로 나누는 점선 (세로 2줄 + 가로 2줄)
private struct StageGridLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for step in 1...2 {
            let x = rect.width * CGFloat(step) / 3
            path.move(to: CGPoint(x: x, y: 1))
            path.addLine(to: CGPoint(x: x, y: rect.height - 1))
            let y = rect.height * CGFloat(step) / 3
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
