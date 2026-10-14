//
//  RecentProjectCard.swift
//  CueFlow
//
//  홈 화면 "최근에 열어본 프로젝트" 카드 한 장.
//  보여줄 글자는 바깥에서 받는다. (데이터 연결은 HomeView에서)
//

import SwiftUI

struct RecentProjectCard: View {
    let lastWorked: String      // 예: "최근 작업 오늘 16:32"
    let title: String           // 예: "뮤지컬 | 레미제라블"
    let summary: String         // 예: "중극장 · 2회 공연"
    let members: String         // 예: "배우 22명 · 스태프 16명 · 총 38명"
    let schedule: String        // 예: "2026.11.14-15 · 아트스페이스 A홀"
    let onRehearsal: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(lastWorked)
                    .font(.footnote)
                    .foregroundStyle(Color.neutral500)

                Spacer()

                // TODO: "수정하기"로 바뀔 예정 (동작 미정)
                Button {
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.brandPrimaryText)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(Color.neutral700)
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(Color.neutral500)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(members)
                    .font(.subheadline)
                    .foregroundStyle(Color.neutral700)
                Text(schedule)
                    .font(.footnote)
                    .foregroundStyle(Color.neutral500)
            }
            .padding(.top, 8)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button("리허설 모드", action: onRehearsal)
                    .buttonStyle(.softPrimary)
                Button("이어서 작업하기", action: onContinue)
                    .buttonStyle(.tertiary)
            }
            .frame(height: 33)
        }
        .lineLimit(1)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 208)
        .background {
            // 피그마: 바탕 #FBFBFF, 그림자 2·2·1 #D1D1D6 → 색상 표에서 가장 가까운 neutral25 · neutral300
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.neutral25)
                .shadow(color: Color.neutral300, radius: 0.5, x: 2, y: 2)
        }
    }
}

#Preview {
    RecentProjectCard(
        lastWorked: "최근 작업 오늘 16:32",
        title: "뮤지컬 | 레미제라블",
        summary: "중극장 · 2회 공연",
        members: "배우 22명 · 스태프 16명 · 총 38명",
        schedule: "2026.11.14-15 · 아트스페이스 A홀",
        onRehearsal: {},
        onContinue: {}
    )
    .frame(width: 386)
    .padding()
}
