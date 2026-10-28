//
//  CueHistorySidebar.swift
//  CueFlow
//
//  Created by 김나현 on 10/29/26.
//

import SwiftUI
import SwiftData

// 큐 카드 우클릭 → History: 통합 큐시트 오른쪽에 뜨는 사이드바 (피그마 Sidebar · History, 폭 313)
struct CueHistorySidebar: View {
    let cue: Cue
    var onClose: () -> Void = {}     // ← 버튼
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            searchField
                .padding(.top, 19)
            currentVersion
                .padding(.top, 10)
            ScrollView {
                timeline
                    .padding(.top, 21)
            }
        }
        .frame(width: 313)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.neutral25, in: .rect(cornerRadius: 10))
    }
}

// 위쪽: ← History · 검색창

extension CueHistorySidebar {
    private var header: some View {
        HStack(spacing: 13) {
            backButton
            Text("History")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.neutral900)
        }
        .padding(.leading, 21)
        .padding(.top, 20)
    }

    private var backButton: some View {
        Button(action: onClose) {
            Image(systemName: "arrow.left")
                .font(.system(size: 14))
                .foregroundStyle(Color.neutral700)
                .frame(width: 17, height: 17)
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.neutral900)
            TextField("", text: $searchText)
                .textFieldStyle(.plain)
                .font(.callout)
        }
        .padding(.leading, 8)
        .frame(height: 24)
        .background(Color.neutral25, in: .capsule)
        .overlay(Capsule().strokeBorder(.black.opacity(0.08)))
        .padding(.horizontal, 15)
    }
}

// 현재 버전 띠: ● #4 Scene · 소품 / 큐 제목 / 트리거 (+ 오른쪽 위치 태그 · 현재 버전)

extension CueHistorySidebar {
    private var currentVersion: some View {
        VStack(alignment: .leading, spacing: 11) {
            sceneLabel
            VStack(alignment: .leading, spacing: 12) {
                cueTitleText
                triggerText
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 70)   // 오른쪽 '현재 버전' 글자와 겹치지 않게
        .padding(.top, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 111, alignment: .top)
        .background(Color.neutral50)
        .overlay(alignment: .topTrailing) { positionTag }
        .overlay(alignment: .bottomTrailing) { currentVersionLabel }
    }

    private var sceneLabel: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(cue.part?.color.accent ?? Color.neutral300)
                .frame(width: 8, height: 8)
            Text(sceneText)
                .font(.subheadline)
                .foregroundStyle(Color.neutral600)
        }
    }

    private var cueTitleText: some View {
        Text(cue.title)
            .font(.system(size: 14.5, weight: .medium))
            .foregroundStyle(Color.neutral900)
            .lineLimit(1)
    }

    private var triggerText: some View {
        Text(cue.trigger?.text ?? "")
            .font(.subheadline)
            .foregroundStyle(Color.neutral600)
            .lineLimit(1)
    }

    private var positionTag: some View {
        Text(cue.position.rawValue)
            .font(.subheadline)
            .foregroundStyle(Color.neutral600)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(Color.neutral200, in: .capsule)
            .padding(.top, 21)
            .padding(.trailing, 11)
    }

    private var currentVersionLabel: some View {
        Text("현재 버전")
            .font(.caption)
            .foregroundStyle(Color.neutral400)
            .padding(.bottom, 21)
            .padding(.trailing, 11)
    }

    // "#4 Scene · 소품"
    private var sceneText: String {
        let sceneNumber = (cue.trigger?.scene?.order ?? 0) + 1
        return "#\(sceneNumber) Scene · \(cue.part?.name ?? "")"
    }
}

// 기록: 날짜 → 그날의 기록들 (왼쪽 세로선 + 점)

extension CueHistorySidebar {
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(dates, id: \.self) { dayGroup($0) }
        }
        .padding(.leading, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 10월 7일 + 그날의 기록들
    private func dayGroup(_ date: String) -> some View {
        VStack(alignment: .leading, spacing: 19) {
            Text(date)
                .font(.caption)
                .foregroundStyle(Color.neutral500)
                .padding(.leading, 3)
            historyList(histories(on: date))
        }
    }

    private func historyList(_ histories: [CueHistory]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(histories) { historyRow($0) }
        }
        .background(alignment: .topLeading) { timelineLine }
    }

    // 첫 점 가운데부터 내려오는 세로선
    private var timelineLine: some View {
        Color.neutral200
            .frame(width: 1)
            .padding(.leading, 5)
            .padding(.top, 5.5)
            .padding(.bottom, 11.5)
    }

    // 기록 한 줄 (+ 이전 · 변경 상자). 다음 기록과 간격: 상자 있으면 18, 없으면 26
    private func historyRow(_ history: CueHistory) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            historyHeader(history)
            if let before = history.before, let after = history.after {
                changeBox(before: before, after: after)
            }
        }
        .padding(.bottom, history.before == nil ? 26 : 18)
    }

    // ○ 트리거 변경 / 김나현님의 수정 ……… 21:32
    private func historyHeader(_ history: CueHistory) -> some View {
        HStack(alignment: .top, spacing: 0) {
            timelineNode(isChange: history.isChange)
                .frame(width: 20, alignment: .leading)
            historyTexts(history)
            Spacer(minLength: 0)
            Text(timeText(history.date))
                .font(.caption)
                .foregroundStyle(Color.neutral400)
        }
        .frame(width: 270)
    }

    private func historyTexts(_ history: CueHistory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(history.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.neutral900)
            Text(history.detail)
                .font(.caption)
                .foregroundStyle(Color.neutral500)
        }
    }

    // 흰 원(11) 안에 점(5): 변경이면 진한 점, 추가 · 생성이면 연한 점
    private func timelineNode(isChange: Bool) -> some View {
        Circle()
            .fill(isChange ? Color.neutral600 : Color.neutral200)
            .frame(width: 5, height: 5)
            .frame(width: 11, height: 11)
            .background(.white, in: .circle)
            .overlay(Circle().strokeBorder(Color.neutral300))
    }

    // 이전 · 변경 상자
    private func changeBox(before: String, after: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            changeLine(label: "이전", value: before, valueColor: .neutral400)
            changeLine(label: "변경", value: after, valueColor: .neutral700)
        }
        .padding(.leading, 16)
        .padding(.vertical, 18)
        .frame(width: 268, alignment: .leading)
        .background(Color.neutral50)
        .padding(.leading, 15)
    }

    private func changeLine(label: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 9) {
            Text(label)
                .foregroundStyle(Color.neutral500)
            Text(value)
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .font(.caption)
    }
}

// 보여줄 기록 고르기 · 날짜 글자

extension CueHistorySidebar {
    // 보여줄 기록: 최근 순, 검색어가 있으면 제목 · 설명에 그 글자가 들어간 것만
    private var shownHistories: [CueHistory] {
        let all = (cue.histories ?? []).sorted { $0.date > $1.date }
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.title.contains(searchText) || $0.detail.contains(searchText) }
    }

    // 기록이 있는 날짜들 ("10월 7일", "10월 6일" …), 최근 순
    private var dates: [String] {
        var result: [String] = []
        for history in shownHistories where result.last != dayText(history.date) {
            result.append(dayText(history.date))
        }
        return result
    }

    // 그 날짜의 기록들
    private func histories(on date: String) -> [CueHistory] {
        shownHistories.filter { dayText($0.date) == date }
    }

    // 2026-10-07 → "10월 7일"
    private func dayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: date)
    }

    // 21:32
    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    let container = try! ModelContainer(for: Cue.self, configurations: .init(isStoredInMemoryOnly: true))
    let cue = Cue(title: "판틴 머리카락 가위", position: .sangsu, order: 1)
    container.mainContext.insert(cue)
    cue.trigger = Trigger(text: "판틴 · 상인과 흥정 직후", order: 0)
    cue.addHistory("큐 생성", detail: "곽소누님이 이 큐를 만들었습니다.", isChange: false)
    cue.addHistory("트리거 변경", detail: "곽소누님의 수정", before: "'Lovely Ladies' 전주", after: "판틴 · 상인과 흥정 직후")

    return CueHistorySidebar(cue: cue)
        .frame(height: 930)
        .modelContainer(container)
}
