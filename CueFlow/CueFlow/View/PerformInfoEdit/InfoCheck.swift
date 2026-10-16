//
//  InfoCheck.swift
//  CueFlow
//
//  Created by 김나현 on 10/16/26.
//

import SwiftUI

// 생성 확인: 기본정보(PerformInfo)에서 입력한 값을 한 번에 보여주는 화면
struct InfoCheck: View {
    let draft: ProductionDraft   // 기본정보에서 입력한 값
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}

    var body: some View {
        CreateStepLayout(
            title: "생성 전 마지막으로 확인하세요",
            subtitle: "큐시트가 만들어지기 전에 공연 정보, 파트 구성, 초대 상태를 한 번에 확인합니다.",
            currentStep: 4,
            onPrevious: onPrevious,
            onNext: onNext
        ) {
            summaryCard
                .padding(.top, 44)
        }
    }
}

//공연 정보 카드

extension InfoCheck {
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardTitle
            divider
            infoRows
        }
        .frame(width: 799, alignment: .leading)
        .frame(minHeight: 460, alignment: .top)
        .background(.white, in: .rect(cornerRadius: 10))
        .overlay(cardBorder)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color.neutral200, lineWidth: 1)
    }

    private var cardTitle: some View {
        Text("프로젝트")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.neutral800)
            .padding(.leading, 50)
            .frame(height: 80)
    }

    private var divider: some View {
        Color.neutral200
            .frame(height: 1)
    }

    private var infoRows: some View {
        VStack(alignment: .leading, spacing: 25) {
            InfoRow(label: "공연명", value: draft.titleText)
            InfoRow(label: "공연 유형", value: draft.genre)
            InfoRow(label: "공연일", value: draft.showDateText)
            InfoRow(label: "공연장", value: draft.venueText)
            InfoRow(label: "객석규모", value: draft.seatCountText)
            InfoRow(label: "주최", value: draft.organizerText)
            InfoRow(label: "러닝타임", value: draft.runningTimeText)
        }
        .padding(.leading, 50)
        .padding(.top, 39)
        .padding(.bottom, 50)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.neutral700)
                .frame(width: 103, alignment: .leading)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.neutral900)
        }
    }
}

private extension ProductionDraft {
    var titleText: String { title.isEmpty ? "-" : title }
    var venueText: String { venue.isEmpty ? "-" : venue }
    var organizerText: String { organizer.isEmpty ? "-" : organizer }

    // 1200 → "1,200석"
    var seatCountText: String {
        guard let seatCount else { return "-" }
        return "\(seatCount.formatted())석"
    }

    // 170 → "170분"
    var runningTimeText: String {
        guard let runningTime else { return "-" }
        return "\(runningTime.formatted())분"
    }

    // "2026.11.14" (하루) 또는 "2026.11.14 ~ 2026.11.30" (기간). 아직 안 골랐으면 -
    var showDateText: String {
        guard let lastShowDate else { return "-" }
        let start = Self.dotDateFormatter.string(from: firstShowDate)
        let end = Self.dotDateFormatter.string(from: lastShowDate)
        return start == end ? start : "\(start) ~ \(end)"
    }

    static let dotDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}

#Preview {
    let draft = ProductionDraft(
        title: "레미제라블",
        lastShowDate: .now,
        venue: "아트스페이스 대극장",
        seatCount: 1200,
        organizer: "극단 오작뮤",
        runningTime: 170
    )
    InfoCheck(draft: draft)
        .frame(width: 1512, height: 982)
}
