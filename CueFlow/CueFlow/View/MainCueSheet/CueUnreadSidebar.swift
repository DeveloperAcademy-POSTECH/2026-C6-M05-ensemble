//
//  CueUnreadSidebar.swift
//  CueFlow
//
//  Created by 김나현 on 10/30/26.
//
//  큐카드 우클릭 → 미확인 수정사항 사이드바. 내가 확인 안 한 큐를 최근에 고친 순서로
//

import SwiftUI
import SwiftData

struct CueUnreadSidebar: View {
    let production: Production
    var onClose: () -> Void = {}
    @Environment(\.myUserID) private var myUserID
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            searchField
                .padding(.top, 17)
            ScrollView {
                list
                    .padding(.top, 23)
                    .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .frame(width: 329)
        .frame(maxHeight: .infinity, alignment: .top)
        .onExitCommand(perform: onClose)   // 검색창에 커서가 있을 때도 Esc로 닫힘
        .background(Color.neutral25.shadow(.drop(color: .black.opacity(0.25), radius: 2, y: 4)), in: .rect(cornerRadius: 10))
    }
}

// 제목 · 검색창

extension CueUnreadSidebar {
    private var header: some View {
        HStack {
            Text("미확인 수정사항")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.neutral700)
            Spacer()
            Text("\(unreadCues.count)건")
                .font(.body)
                .foregroundStyle(Color.neutral800)
        }
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
    }
}

// 목록

extension CueUnreadSidebar {
    private var list: some View {
        VStack(alignment: .leading, spacing: 25) {
            ForEach(shownCues) { group($0) }
        }
    }

    private func group(_ cue: Cue) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(editorName(of: cue))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.neutral900)
                Spacer()
                Text(Self.dateText(lastEditDate(of: cue)))
                    .font(.caption)
                    .foregroundStyle(Color.neutral400)
            }
            UnreadCueCard(cue: cue)
        }
    }
}

// 데이터

extension CueUnreadSidebar {
    // 내가 확인 안 한 큐 (최근에 고친 순)
    private var unreadCues: [Cue] {
        let cues = (production.parts ?? []).flatMap { $0.cues ?? [] }
        return cues.filter { $0.check(byUserID: myUserID) == nil }
            .sorted { lastEditDate(of: $0) > lastEditDate(of: $1) }
    }

    private var shownCues: [Cue] {
        guard !searchText.isEmpty else { return unreadCues }
        return unreadCues.filter { $0.title.contains(searchText) || ($0.trigger?.text ?? "").contains(searchText) }
    }

    private func latestHistory(of cue: Cue) -> CueHistory? {
        (cue.histories ?? []).max { $0.date < $1.date }
    }

    private func lastEditDate(of cue: Cue) -> Date { latestHistory(of: cue)?.date ?? cue.createdAt }

    // TODO: CueHistory에 editor가 생기면 교체. 지금은 기록 글의 "님" 앞 이름
    private func editorName(of cue: Cue) -> String {
        guard let detail = latestHistory(of: cue)?.detail, let range = detail.range(of: "님") else { return "" }
        return String(detail[..<range.lowerBound])
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: date)
    }
}

// 사이드바 안의 큐 카드

private struct UnreadCueCard: View {
    let cue: Cue

    var body: some View {
        HStack(alignment: .top, spacing: 1) {
            numberCircle
            texts
            Spacer(minLength: 0)
            positionTag
        }
        .padding(.leading, 13)
        .padding(.trailing, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(partColor.background, lineWidth: 1.32))
    }
}

extension UnreadCueCard {
    private var numberCircle: some View {
        Text(String(format: "%02d", cue.order))
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(partColor.number)
            .frame(width: 20, height: 20)
            .background(partColor.background, in: .circle)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sceneCode)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.neutral900)
                Text(cue.trigger?.scene?.title ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.neutral500)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(cue.trigger?.text ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.neutral800)
                Text(cue.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.neutral800)
            }
        }
        .lineLimit(1)
    }

    private var positionTag: some View {
        Text(cue.position.rawValue)
            .font(.system(size: 10))
            .foregroundStyle(partColor.number)
            .padding(.horizontal, 8)
            .frame(height: 18)
            .background(partColor.background, in: .capsule)
    }

    private var sceneCode: String { "#\((cue.trigger?.scene?.order ?? 0) + 1) Scene" }
    private var partColor: PartColor { cue.part?.color ?? PartColor.at(0) }
}
