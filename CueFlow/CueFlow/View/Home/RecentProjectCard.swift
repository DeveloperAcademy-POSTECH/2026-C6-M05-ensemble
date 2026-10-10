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
            Text(lastWorked)
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(members)
                    .font(.subheadline)
                Text(schedule)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        // 디자인 시스템 Shadow/lg (#101828, 3% · 8% 두 겹)
        .shadow(color: Color(red: 16 / 255, green: 24 / 255, blue: 40 / 255).opacity(0.03), radius: 3, y: 4)
        .shadow(color: Color(red: 16 / 255, green: 24 / 255, blue: 40 / 255).opacity(0.08), radius: 8, y: 12)
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
