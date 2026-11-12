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
                .padding(.horizontal, 15)
                .padding(.top, 26.5)   // 피그마 검색창 위에서 67 (20.5 + 제목 줄 20 + 26.5)
            ScrollView {
                list
                    .padding(.horizontal, 14)
                    .padding(.top, 28)   // 검색창 아래 28 (위에서 119)
                    .padding(.bottom, 20)
            }
        }
        .padding(.top, 20.5)   // 제목 줄(20) 가운데를 « 가운데(위에서 30.5)에 맞춤
        .frame(width: 313)
        .frame(maxHeight: .infinity, alignment: .top)
        .onEscape(perform: onClose)   // 검색창에 커서가 있을 때도 Esc로 닫힘
        .background(Color.neutral25.shadow(.drop(color: .black.opacity(0.25), radius: 2, y: 4)), in: .rect(cornerRadius: 10))
    }
}

// « 제목 · 검색창

extension CueUnreadSidebar {
    // (« 자리) 미확인 수정사항 ······ N건. « 버튼은 MainCueSheetView가 고정 위치에 그림
    private var header: some View {
        HStack {
            Text("미확인 수정사항")
                .font(.appTitle3.weight(.semibold))   // 피그마 Title 3/Emphasized 15/20
                .foregroundStyle(Color.neutral900)
            Spacer()
            Text("\(unreadCues.count)건")
                .font(.appTitle3)   // 피그마 Title 3/Regular 15/20
                .foregroundStyle(Color.neutral900)
        }
        .padding(.leading, 45)    // « (왼쪽 16 + 폭 19) + 간격 10
        .padding(.trailing, 14)
    }

    private var searchField: some View {
        HStack(spacing: 2) {
            Image(systemName: "magnifyingglass")
                .font(.app(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.neutral900)
            TextField("", text: $searchText)
                .textFieldStyle(.plain)
                .font(.appCallout)
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(Color.sidebarSearch, in: .capsule)
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
                    .font(.appCallout.weight(.semibold))
                    .foregroundStyle(Color.neutral900)
                Spacer()
                Text(Self.dateText(lastEditDate(of: cue)))
                    .font(.appCaption)
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
        HStack(alignment: .top, spacing: 4) {
            numberCircle
            texts
            Spacer(minLength: 0)
            positionTag
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .padding(.top, 13)
        .frame(maxWidth: .infinity, minHeight: 91, alignment: .topLeading)   // 피그마 카드 높이 91
        .background(Color.surfaceWhite, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(partColor.sidebarBorder, lineWidth: 1.32))
    }
}

extension UnreadCueCard {
    private var numberCircle: some View {
        Text(String(format: "%02d", cue.order))
            .font(.app(size: 8, weight: .medium))
            .foregroundStyle(partColor.number)
            .frame(width: 20, height: 20)
            .background(partColor.sidebarChip, in: .circle)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sceneCode)
                    .font(.app(size: 12, weight: .semibold))
                    .foregroundStyle(Color.neutral900)
                Text(cue.trigger?.scene?.title ?? "")
                    .font(.app(size: 10))
                .foregroundStyle(Color.neutral500)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(cue.trigger?.text ?? "")
                    .font(.app(size: 10))
                    .foregroundStyle(Color.neutral800)
                Text(cue.title)
                    .font(.app(size: 12, weight: .semibold))
                    .foregroundStyle(Color.neutral800)
            }
        }
        .lineLimit(1)
    }

    private var positionTag: some View {
        Text(cue.position.rawValue)
            .font(.app(size: 10))
            .foregroundStyle(partColor.number)
            .padding(.horizontal, 8)
            .frame(height: 18)
            .background(partColor.sidebarChip, in: .capsule)
    }

    private var sceneCode: String { "#\((cue.trigger?.scene?.order ?? 0) + 1) Scene" }
    private var partColor: PartColor { cue.part?.color ?? PartColor.at(0) }
}
