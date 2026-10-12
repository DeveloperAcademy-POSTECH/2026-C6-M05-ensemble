//
//  RehearsalCueList.swift
//  CueFlow
//
//  리허설 모드 큐 목록 (피그마 Card/큐 목록).
//  메인 큐시트와 같은 데이터(장면 → 트리거 → 큐)를 표로 읽어서 보여준다. 한 줄 = 트리거 하나.
//  지금 큐(트리거) 줄은 연보라 + 왼쪽 막대, 이전 큐 / 다음 큐로 이동.
//

import SwiftUI

// 표 열 너비 (피그마 기준). 큐 열은 남는 만큼.
private enum CueListColumn {
    static let scene: CGFloat = 130
    static let trigger: CGFloat = 220
    static let position: CGFloat = 100
    static let part: CGFloat = 110
}

struct RehearsalCueList: View {
    let sceneCode: String          // "S#3"
    let triggers: [Trigger]        // 지금 장면의 트리거 (순서대로)
    let parts: [Part]              // 파트 필터 칩
    @Binding var currentIndex: Int // 지금 큐 = 몇 번째 트리거
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

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
        RehearsalCard {
            VStack(spacing: 0) {
                header
                Divider()
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
                                        isCurrent: index == currentIndex
                                    )
                                    .id(index)
                                    .onTapGesture { currentIndex = index }
                                    Divider()
                                }
                            }
                        }
                    }
                    // 지금 큐가 바뀌면 그 줄이 보이게
                    .onChange(of: currentIndex) {
                        withAnimation { proxy.scrollTo(currentIndex, anchor: .center) }
                    }
                }
                .overlay { columnLines }
            }
        }
    }

    // "큐 목록  5개 큐  (전체)(무대)(소품)…      < 이전 큐  다음 큐 >"
    private var header: some View {
        HStack(spacing: 10) {
            Text("큐 목록")
                .font(.body.weight(.semibold))
            Text("\(cueCount)개 큐")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                filterChip("전체", isSelected: selectedPart == nil) { selectedPart = nil }
                ForEach(parts) { part in
                    filterChip(part.name, isSelected: selectedPart == part) { selectedPart = part }
                }
            }
            .padding(.leading, 10)

            Spacer()

            Button(action: onPrevious) {
                Label("이전 큐", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.secondary)
            .frame(width: 78, height: 28)
            .disabled(!canGoPrevious)
            .opacity(canGoPrevious ? 1 : 0.4)

            Button(action: onNext) {
                HStack(spacing: 4) {
                    Text("다음 큐")
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.softPrimaryCompat)
            .frame(width: 75, height: 28)
            .disabled(!canGoNext)
            .opacity(canGoNext ? 1 : 0.4)
            .keyboardShortcut(.space, modifiers: [])   // 스페이스바 = 다음 큐
        }
        .font(.callout)
        .padding(.leading, 22)
        .padding(.trailing, 18)
        .frame(height: 56)
    }

    // 파트 필터 알약. 고른 것은 회색 바탕.
    // TODO: 셀리나 PartFilterTabBar(PR #40)와 모양 · 동작 합치기
    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 11)
                .frame(height: 23)
                .background(isSelected ? Color.secondary : Color.clear, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.5), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    // 열 제목: 씬 & 큐 | 트리거 | 큐 | 위치 | 파트
    private var columnTitles: some View {
        HStack(spacing: 0) {
            columnTitle("씬 & 큐").frame(width: CueListColumn.scene, alignment: .leading)
            columnTitle("트리거").frame(width: CueListColumn.trigger, alignment: .leading)
            columnTitle("큐").frame(maxWidth: .infinity, alignment: .leading)
            columnTitle("위치").frame(width: CueListColumn.position, alignment: .leading)
            columnTitle("파트").frame(width: CueListColumn.part, alignment: .leading)
        }
        .frame(height: 36)
        .overlay { columnLines }
    }

    private func columnTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 14)
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

// 표 한 줄 = 트리거 하나. 큐가 여러 개면 큐 · 위치 · 파트가 아래로 쌓인다.
struct CueListRow: View {
    let code: String       // "S#3 - 1"
    let trigger: Trigger
    let cues: [Cue]
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(code)
                .font(.callout.weight(isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? Color.brandPrimaryText : Color.primary)
                .padding(.leading, 20)
                .frame(width: CueListColumn.scene, height: 30, alignment: .leading)

            Text(trigger.text)
                .font(.callout)
                .lineLimit(1)
                .padding(.leading, 14)
                .frame(width: CueListColumn.trigger, height: 30, alignment: .leading)

            column(maxWidth: .infinity) { cue in
                CueListCard(cue: cue)
                    .padding(.horizontal, 12)
            }

            column(width: CueListColumn.position) { cue in
                Text(cue.position.rawValue)
                    .font(.caption)
                    .foregroundStyle(Color.brandPrimaryText)
                    .padding(.horizontal, 10)
                    .frame(height: 19)
                    .background(Color.brandPrimarySubtle, in: Capsule())
                    .padding(.leading, 14)
            }

            column(width: CueListColumn.part) { cue in
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(cue.part?.color.accent ?? Color.secondary)
                        .frame(width: 4, height: 14)
                    Text(cue.part?.name ?? "")
                        .font(.callout)
                }
                .padding(.leading, 14)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrent ? Color.brandPrimarySubtle.opacity(0.5) : Color.clear)
        .overlay(alignment: .leading) {
            if isCurrent {
                Rectangle()
                    .fill(Color.brandPrimaryHover)
                    .frame(width: 5)
            }
        }
        .contentShape(Rectangle())   // 빈 곳을 눌러도 이 줄이 지금 큐가 되게
    }

    // 큐마다 한 칸씩 (높이 30, 간격 6) 아래로 쌓는 열
    private func column<Content: View>(
        width: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        @ViewBuilder content: @escaping (Cue) -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(cues) { cue in
                content(cue)
                    .frame(height: 30, alignment: .leading)
            }
        }
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: maxWidth, alignment: .leading)
    }
}

// 표 안 큐 카드: 왼쪽 파트 색 막대 + 큐 제목
struct CueListCard: View {
    let cue: Cue

    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 2)
                .fill(cue.part?.color.accent ?? Color.secondary)
                .frame(width: 4)
            Text(cue.title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(height: 30)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
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
