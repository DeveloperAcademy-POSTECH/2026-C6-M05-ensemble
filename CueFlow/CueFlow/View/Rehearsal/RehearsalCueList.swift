//
//  RehearsalCueList.swift
//  CueFlow
//
//  리허설 모드 큐 목록 (피그마 리허설모드_무대배치01 · ver1). 제목 · 필터 · 버튼은 표 상자 밖 위에.
//  메인 큐시트와 같은 데이터(장면 → 트리거 → 큐)를 표로 읽어서 보여준다. 한 줄 = 트리거 하나.
//  지금 큐(트리거) 줄은 연보라 + 왼쪽 막대, 지난 큐는 흐리게. 이전 큐 / 다음 큐로 이동.
//

import SwiftUI

// 표 열 너비 (피그마 리허설모드_ver1 기준). 큐 열은 남는 만큼.
private enum CueListColumn {
    static let scene: CGFloat = 110
    static let trigger: CGFloat = 240
    static let position: CGFloat = 100
    static let part: CGFloat = 117
    static let cueHeight: CGFloat = 42   // 큐 한 줄 높이
}

struct RehearsalCueList<SceneControls: View>: View {
    let sceneCode: String          // "S#3"
    let triggers: [Trigger]        // 지금 장면의 트리거 (순서대로)
    let parts: [Part]              // 파트 필터 칩
    @Binding var currentIndex: Int // 지금 큐 = 몇 번째 트리거
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let sceneControls: SceneControls   // < > 장면 이동 · 장면 선택 (이전 큐 왼쪽)

    @State private var selectedPart: Part?   // nil = 전체

    // 고른 파트의 큐만 (트리거 안 순서대로)
    private func cues(of trigger: Trigger) -> [Cue] {
        (trigger.cues ?? [])
            .filter { selectedPart == nil || $0.part == selectedPart }
            .sorted { $0.order < $1.order }
    }

    private var cueCount: Int {
        triggers.reduce(0) { $0 + cues(of: $1).count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // "큐 목록  5개 큐"
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("큐 목록")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.neutral800)
                Text("\(cueCount)개 큐")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.neutral600)
            }

            // 파트 필터 | 장면 이동 · 이전 큐 · 다음 큐
            HStack(spacing: 8) {
                PartFilterTabBar(parts: parts, selectedPart: $selectedPart, isCompact: true)
                Spacer()
                sceneControls
                previousButton
                nextButton
            }

            table
        }
    }

    // 표: 회색 테두리 상자 안에 열 제목 + 줄들
    private var table: some View {
        VStack(spacing: 0) {
            columnTitles
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(triggers.enumerated()), id: \.element.id) { index, trigger in
                            let rowCues = cues(of: trigger)
                            // 필터로 큐가 하나도 없는 트리거는 숨긴다 (지금 큐는 남긴다)
                            if !rowCues.isEmpty || index == currentIndex {
                                CueListRow(
                                    code: "\(sceneCode) - \(index + 1)",
                                    trigger: trigger,
                                    cues: rowCues,
                                    isCurrent: index == currentIndex,
                                    isPast: index < currentIndex
                                )
                                .id(index)
                                .onTapGesture { currentIndex = index }
                                Divider()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)   // 큐가 0개여도 표 폭을 꽉 채워서 세로선이 열 제목과 맞게
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollIndicators(.never)   // 스크롤바 자리만큼 줄이 좁아져 열 제목과 어긋나지 않게
                // 지금 큐가 바뀌면 그 줄이 보이게
                .onChange(of: currentIndex) {
                    withAnimation { proxy.scrollTo(currentIndex, anchor: .center) }
                }
            }
            .overlay { columnLines }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.neutral25)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.neutral300, lineWidth: 1)
        }
    }

    // "< 이전 큐": 흰 바탕 + 회색 테두리
    private var previousButton: some View {
        Button(action: onPrevious) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.neutral600)
                Text("이전 큐")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.neutral800)
            }
            .frame(width: 78, height: 36)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.neutral400, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(!canGoPrevious)
        .opacity(canGoPrevious ? 1 : 0.4)
    }

    // "다음 큐 >": 연보라 바탕 + 흰 글자. 스페이스바로도 누른다
    private var nextButton: some View {
        Button(action: onNext) {
            HStack(spacing: 4) {
                Text("다음 큐")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .buttonStyle(.softPrimaryCompat)
        .frame(width: 75, height: 36)
        .disabled(!canGoNext)
        .opacity(canGoNext ? 1 : 0.4)
        .keyboardShortcut(.space, modifiers: [])   // 스페이스바 = 다음 큐
    }

    // 열 제목: 씬 & 큐 | 트리거 | 큐 | 위치 | 파트
    private var columnTitles: some View {
        HStack(spacing: 0) {
            columnTitle("씬 & 큐").frame(width: CueListColumn.scene)
            columnTitle("트리거").frame(width: CueListColumn.trigger)
            columnTitle("큐").frame(maxWidth: .infinity)
            columnTitle("위치").frame(width: CueListColumn.position)
            columnTitle("파트").frame(width: CueListColumn.part)
        }
        .frame(height: 36)
        .overlay { columnLines }
    }

    private func columnTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(Color.neutral800)
    }

    // 열 사이 세로선
    private var columnLines: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: CueListColumn.scene)
            Divider()
            Spacer().frame(width: CueListColumn.trigger - 1)
            Divider()
            Spacer()
            Divider()
            Spacer().frame(width: CueListColumn.position - 1)
            Divider()
            Spacer().frame(width: CueListColumn.part - 1)
        }
        .allowsHitTesting(false)
    }
}

// 표 한 줄 = 트리거 하나. 큐가 여러 개면 큐 · 위치 · 파트가 한 줄(42pt)씩 아래로 쌓이고 사이에 가로선.
struct CueListRow: View {
    let code: String       // "S#3 - 1"
    let trigger: Trigger
    let cues: [Cue]
    let isCurrent: Bool
    var isPast = false     // 이미 지나간 큐 → 흐리게

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(code)
                .font(.system(size: 15, weight: isCurrent ? .semibold : .medium))
                .foregroundStyle(isCurrent ? Color.neutral900 : Color.neutral800)
                .padding(.leading, 20)
                .frame(width: CueListColumn.scene, height: CueListColumn.cueHeight, alignment: .leading)

            Text(trigger.text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.neutral900)
                .lineLimit(1)
                .padding(.leading, 20)
                .frame(width: CueListColumn.trigger, height: CueListColumn.cueHeight, alignment: .leading)

            VStack(spacing: 0) {
                ForEach(Array(cues.enumerated()), id: \.element.id) { index, cue in
                    if index > 0 { Divider() }
                    cueLine(cue)
                }
            }
        }
        .opacity(isPast ? 0.4 : 1)   // 글자 · 태그만 흐리게 (줄 바탕 · 가로선은 그대로)
        .frame(maxWidth: .infinity, minHeight: CueListColumn.cueHeight, alignment: .topLeading)
        .background(isCurrent ? Color.brandPrimarySubtle.opacity(0.2) : Color.neutral25)
        .overlay(alignment: .leading) {
            if isCurrent {
                Rectangle()
                    .fill(Color.brandPrimaryHover)
                    .frame(width: 5)
            }
        }
        .contentShape(Rectangle())   // 빈 곳을 눌러도 이 줄이 지금 큐가 되게
    }

    // 큐 한 줄: 큐 제목 | 위치 태그(가운데) | 파트(가운데)
    private func cueLine(_ cue: Cue) -> some View {
        HStack(spacing: 0) {
            Text(cue.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.neutral800)
                .lineLimit(1)
                .padding(.leading, 22)
                .frame(maxWidth: .infinity, alignment: .leading)

            positionTag(cue)
                .frame(width: CueListColumn.position)

            Text(cue.part?.name ?? "")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.neutral900)
                .frame(width: CueListColumn.part)
        }
        .frame(height: CueListColumn.cueHeight)
    }

    // 위치 태그. 무대 큐는 눌러서 9구역 중 하나를 고른다 → 미니맵에서 그 구역으로 옮겨진다
    @ViewBuilder
    private func positionTag(_ cue: Cue) -> some View {
        if cue.position == .stage {
            Menu {
                ForEach(0..<9, id: \.self) { cell in
                    Button("\(cell + 1)구역") { cue.stageCell = cell }
                }
                Divider()
                Button("구역 미정") { cue.stageCell = nil }
            } label: {
                tagLabel(cue.stageCell.map { "무대 \($0 + 1)" } ?? "무대", color: tagColor(cue))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("무대 몇 구역인지 고르기")
        } else {
            tagLabel(cue.position.rawValue, color: tagColor(cue))
        }
    }

    // 태그 색 = 그 큐 파트의 색 (무대 보라 · 소품 하늘 · 의상 남색 · 조명 파랑 · 음향 초록)
    private func tagColor(_ cue: Cue) -> PartColor {
        cue.part?.color ?? PartColor.at(0)
    }

    private func tagLabel(_ text: String, color: PartColor) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color.number)
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(color.background, in: Capsule())
    }
}

// "다음 큐" 버튼: 연보라 배경 + 흰 글자
// TODO: #41 머지 후 .buttonStyle(.softPrimary)로 교체하고 이건 지우기
struct SoftPrimaryCompatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                configuration.isPressed ? Color.brandPrimary : Color.brandPrimaryHover,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

extension ButtonStyle where Self == SoftPrimaryCompatButtonStyle {
    static var softPrimaryCompat: SoftPrimaryCompatButtonStyle { SoftPrimaryCompatButtonStyle() }
}

#Preview {
    RehearsalView(production: RehearsalPreviewData.production) { }
        .frame(width: 1512, height: 932)
}
